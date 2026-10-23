#!/usr/bin/env bash
# Aero Dark — make AeroThemePlasma's notification popups follow light/dark.
#
# The notification applet's QML is compiled into its plugin, so (unlike the Start menu and tray)
# it can't be changed with a private copy. This patches ATP's source for that one applet and
# rebuilds it, the same way ATP's own installer builds it. The patched popups switch by
# themselves: light with ATP's theme, dark with Aero Dark.
#
#   ./dark-notifications.sh [path to your aerothemeplasma folder]
#
# Without a path it downloads the matching AeroThemePlasma source from GitHub.
# Needs the build tools you already used to install AeroThemePlasma, and sudo to install.
# Updating AeroThemePlasma replaces the applet again; just re-run this afterwards.
set -eu

say()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

for tool in git cmake python3; do have "$tool" || { warn "$tool is needed."; exit 1; }; done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/aerodark-notifications.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

if [ $# -ge 1 ]; then
  [ -d "$1/plasma/plasmoids/src/notifications_src" ] || { warn "$1 doesn't look like an aerothemeplasma folder."; exit 1; }
  say "Using the AeroThemePlasma source in $1"
  cp -a "$1/plasma/plasmoids/src/notifications_src" "$WORK/notifications_src"
  ROOT_CMAKE="$1/CMakeLists.txt"
else
  ver="$(plasmashell --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -n1 || true)"
  repo="https://github.com/aeroshell-desktop/aerothemeplasma.git"
  branch=""
  if [ -n "$ver" ] && git ls-remote --exit-code --heads "$repo" "Plasma/$ver" >/dev/null 2>&1; then branch="Plasma/$ver"; fi
  say "Downloading AeroThemePlasma source${branch:+ ($branch)}"
  git clone --quiet --depth 1 ${branch:+-b "$branch"} "$repo" "$WORK/atp"
  cp -a "$WORK/atp/plasma/plasmoids/src/notifications_src" "$WORK/notifications_src"
  ROOT_CMAKE="$WORK/atp/CMakeLists.txt"
fi

# Newer AeroThemePlasma (Plasma 6.8+) builds everything as one project, and the applet's folder has
# no project of its own. Wrap it in a copy of the top-level project that builds only this applet.
SRC="$WORK/notifications_src"
if ! grep -q '^ *project *(' "$SRC/CMakeLists.txt"; then
  [ -f "$ROOT_CMAKE" ] || { warn "Can't find AeroThemePlasma's top-level CMakeLists.txt."; exit 1; }
  mkdir -p "$WORK/wrap"
  mv "$SRC" "$WORK/wrap/notifications_src"
  python3 - "$ROOT_CMAKE" "$WORK/wrap/CMakeLists.txt" <<'PY'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
s = re.sub(r"(?m)^\s*add_subdirectory\(.*\)\s*$\n?", "", s)
s = s.replace("feature_summary(", "add_subdirectory(notifications_src)\nfeature_summary(", 1) \
    if "feature_summary(" in s else s + "\nadd_subdirectory(notifications_src)\n"
open(sys.argv[2], "w", encoding="utf-8").write(s)
PY
  SRC="$WORK/wrap"
  PATCH_DIR="$SRC/notifications_src/notifications"
else
  PATCH_DIR="$SRC/notifications"
fi

say "Patching the notification popup to follow light/dark"
python3 - "$PATCH_DIR" <<'PY'
import os, re, sys
ui = sys.argv[1]
FLAG = ("    property SystemPalette adPal: SystemPalette { colorGroup: SystemPalette.Active } // Aero Dark\n"
        "    readonly property bool adDark: adPal.window.hslLightness < 0.5 // Aero Dark\n")
def edit(rel, swaps):
    p = os.path.join(ui, rel)
    s = open(p, encoding="utf-8").read()
    if "property bool adDark" not in s:
        s, n = re.subn(r"(?m)^([A-Z][A-Za-z0-9_.]* *\{ *\n)", lambda m: m.group(1) + FLAG, s, count=1)
        if n != 1:
            sys.exit(f"couldn't find the root object in {rel}")
    for old, new in swaps:
        if old not in s:
            sys.exit(f"{rel}: expected text not found: {old}")
        s = s.replace(old, new)
    open(p, "w", encoding="utf-8").write(s)
# The popup's own colour set (View) is what its text already follows, so the background reads the
# same thing: dark whenever the popup's text is light. The system palette is a fallback.
DARK = "(adDark || backgroundRect.Kirigami.Theme.textColor.hslLightness > 0.5)"
edit("NotificationPopup.qml", [
    ('GradientStop { position: 0.0; color: "#ffffff" }', f'GradientStop {{ position: 0.0; color: {DARK} ? "#2a2b2e" : "#ffffff" }}'),
    ('GradientStop { position: 1.0; color: "#d3d1d2" }', f'GradientStop {{ position: 1.0; color: {DARK} ? "#141517" : "#d3d1d2" }}'),
])
edit("components/ThumbnailStrip.qml", [
    ('color: "#898c95"', 'color: (adDark ? "#4a4d52" : "#898c95")'),
])
edit("components/NotificationHeader.qml", [
    ('? "#9d3939" : "#1d3287"', '? (adLight() ? "#9d3939" : "#ff7b6b") : (adLight() ? "#1d3287" : "#6cc4ff")'),
    ('    readonly property bool adDark: adPal.window.hslLightness < 0.5 // Aero Dark\n',
     '    readonly property bool adDark: adPal.window.hslLightness < 0.5 // Aero Dark\n'
     '    function adLight() { return !adDark && Kirigami.Theme.textColor.hslLightness <= 0.5 } // Aero Dark\n'),
])
print("patched")
PY

say "Building the notification applet (this takes a minute)"
cd "$SRC"
gen=""
if have ninja; then gen="-G Ninja"; fi
cmake -S . -B build -DCMAKE_INSTALL_PREFIX=/usr $gen >/dev/null
cmake --build build
say "Installing it (asks for your password)"
SU=sudo; have sudo || SU=doas
"$SU" cmake --install build >/dev/null

so="$(find /usr/lib* -path '*plasma/applets/*wackyideas.notifications*.so' 2>/dev/null | head -n1)"
if [ -n "$so" ] && grep -q "adDark" "$so"; then say "Installed the patched applet: $so"
else warn "Couldn't confirm the patched applet was installed${so:+ at $so}."; fi

say "Restarting the Plasma shell"
if have kquitapp6 && have kstart; then
  kquitapp6 plasmashell >/dev/null 2>&1 || true; sleep 2; kstart plasmashell >/dev/null 2>&1 &
else
  (plasmashell --replace >/dev/null 2>&1 &)
fi
say "Done. Notifications now follow Aero Dark. Re-run this after updating AeroThemePlasma."
