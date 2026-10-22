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
else
  ver="$(plasmashell --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -n1 || true)"
  repo="https://github.com/aeroshell-desktop/aerothemeplasma.git"
  branch=""
  if [ -n "$ver" ] && git ls-remote --exit-code --heads "$repo" "Plasma/$ver" >/dev/null 2>&1; then branch="Plasma/$ver"; fi
  say "Downloading AeroThemePlasma source${branch:+ ($branch)}"
  git clone --quiet --depth 1 ${branch:+-b "$branch"} "$repo" "$WORK/atp"
  cp -a "$WORK/atp/plasma/plasmoids/src/notifications_src" "$WORK/notifications_src"
fi

say "Patching the notification popup to follow light/dark"
python3 - "$WORK/notifications_src/notifications" <<'PY'
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
edit("NotificationPopup.qml", [
    ('GradientStop { position: 0.0; color: "#ffffff" }', 'GradientStop { position: 0.0; color: (adDark ? "#2a2b2e" : "#ffffff") }'),
    ('GradientStop { position: 1.0; color: "#d3d1d2" }', 'GradientStop { position: 1.0; color: (adDark ? "#141517" : "#d3d1d2") }'),
])
edit("components/NotificationHeader.qml", [
    ('? "#9d3939" : "#1d3287"', '? (adDark ? "#ff7b6b" : "#9d3939") : (adDark ? "#6cc4ff" : "#1d3287")'),
])
print("patched")
PY

say "Building the notification applet (this takes a minute)"
cd "$WORK/notifications_src"
gen=""; cmd="make"
if have ninja; then gen="-G Ninja"; cmd="ninja"; fi
cmake -S . -B build -DCMAKE_INSTALL_PREFIX=/usr $gen >/dev/null
cmake --build build
say "Installing it (asks for your password)"
sudo cmake --install build >/dev/null

say "Restarting the Plasma shell"
if have kquitapp6 && have kstart; then
  kquitapp6 plasmashell >/dev/null 2>&1 || true; sleep 2; kstart plasmashell >/dev/null 2>&1 &
else
  (plasmashell --replace >/dev/null 2>&1 &)
fi
say "Done. Notifications now follow Aero Dark. Re-run this after updating AeroThemePlasma."
