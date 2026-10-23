#!/usr/bin/env bash
# Aero Dark — make AeroThemePlasma's UAC (polkit) prompt follow light/dark.
#
# The prompt's QML is compiled into uac-polkit-agent, so this patches its source and rebuilds it,
# the same way AeroThemePlasma's installer builds it. The patched prompt switches by itself:
# light with ATP's theme, dark with Aero Dark (labels already follow the theme; this fixes the
# hard-coded white panel, separator, footer and OK/Cancel text).
#
#   ./dark-uac.sh [path to a uac-polkit-agent source folder]
#
# Tip: AeroThemePlasma's installer keeps its sources, so the matching one is usually at
#   <your aerothemeplasma folder>/repos/uac-polkit-agent
#
# Without a path it downloads the source (GitHub, or gitgud.io as a fallback). Needs the build tools you already used
# to install AeroThemePlasma, and sudo to install. Re-run after updating AeroThemePlasma.
set -eu

say()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

for tool in git cmake python3; do have "$tool" || { warn "$tool is needed."; exit 1; }; done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/aerodark-uac.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

if [ $# -ge 1 ]; then
  [ -f "$1/qml/QuickAuthDialog.qml" ] || { warn "$1 doesn't look like a uac-polkit-agent folder."; exit 1; }
  say "Using the source in $1"
  cp -a "$1" "$WORK/uac"
else
  # the project moved from gitgud.io to GitHub; try GitHub first
  repo="https://github.com/aeroshell-desktop/uac-polkit-agent.git"
  git ls-remote --exit-code "$repo" >/dev/null 2>&1 || repo="https://gitgud.io/aeroshell/uac-polkit-agent.git"
  ver="$(plasmashell --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -n1 || true)"
  branch=""
  if [ -n "$ver" ] && git ls-remote --exit-code --heads "$repo" "Plasma/$ver" >/dev/null 2>&1; then branch="Plasma/$ver"; fi
  say "Downloading uac-polkit-agent${branch:+ ($branch)}"
  git clone --quiet --depth 1 ${branch:+-b "$branch"} "$repo" "$WORK/uac"
fi
rm -rf "$WORK/uac/build"

say "Patching the prompt to follow light/dark"
python3 - "$WORK/uac/qml/QuickAuthDialog.qml" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
if "property bool adDark" not in s:
    flag = ("    property SystemPalette adPal: SystemPalette { colorGroup: SystemPalette.Active } // Aero Dark\n"
            "    readonly property bool adDark: adPal.window.hslLightness < 0.5 // Aero Dark\n")
    s, n = re.subn(r"(?m)^(Kirigami\.AbstractApplicationWindow *\{ *\n)", lambda m: m.group(1) + flag, s, count=1)
    if n != 1:
        sys.exit("couldn't find the dialog's root object")

def swap(old, new, count=None):
    global s
    found = s.count(old)
    if found == 0 or (count is not None and found != count):
        sys.exit(f"expected text not found (or found {found}x): {old!r}")
    s = s.replace(old, new)

swap('    color: "white"\n', '    color: (adDark ? "#1c1d1f" : "white")\n', 1)                 # dialog body
swap('color: "#dfdfdf"\n', 'color: (adDark ? "#2b2d30" : "#dfdfdf")\n')                      # separator + footer border
swap('color: "#f0f0f0"', 'color: (adDark ? "#141516" : "#f0f0f0")', 1)                       # footer
# plain Text items default to black: give them the theme's text colour in dark mode
s, n = re.subn(r"(?m)^(\s*)(contentItem: Text \{|Text \{)\n",
               lambda m: f'{m.group(1)}{m.group(2)}\n{m.group(1)}    color: (adDark ? "#ececec" : "black") // Aero Dark\n', s)
if n < 3:
    sys.exit(f"expected the OK/Cancel/error texts, found {n}")
open(p, "w", encoding="utf-8").write(s)
print("patched")
PY

say "Building uac-polkit-agent (this takes a minute)"
cd "$WORK/uac"
gen=""; if have ninja; then gen="-G Ninja"; fi
# same install layout as AeroThemePlasma's installer, so the existing service picks up the new binary
UAC_LIBEXEC_DIR="${UAC_LIBEXEC_DIR:-lib}"
have dnf && UAC_LIBEXEC_DIR="libexec/kf6"
cmake -S . -B build -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBEXECDIR="$UAC_LIBEXEC_DIR" $gen >/dev/null
cmake --build build
say "Installing it (asks for your password)"
SU=sudo; have sudo || SU=doas
"$SU" cmake --install build >/dev/null

say "Restarting the agent"
systemctl --user restart uac-polkit-agent.service >/dev/null 2>&1 \
  || systemctl --user restart plasma-polkit-agent.service >/dev/null 2>&1 \
  || warn "Couldn't restart it automatically; it'll use the new look after you log out and back in."
say "Done. The UAC prompt now follows Aero Dark. Re-run this after updating AeroThemePlasma."
