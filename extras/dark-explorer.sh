#!/usr/bin/env bash
# Aero Dark — make linux-explorer (github.com/actuallyaridan/linux-explorer) follow light/dark.
#
# Explorer keeps its Windows 7 colours in one table (src/aero/palette.h) and draws its command bar
# from bundled images. This patches both so that, when your colour scheme is dark (Aero Dark),
# Explorer starts with VistaVG-black panels, light text, a black-glass command bar and blue
# hover pills; with ATP's light theme it looks exactly as before. Then it rebuilds and installs it.
#
#   ./dark-explorer.sh [path to a linux-explorer source folder]
#
# Without a path it downloads the newest release from GitHub. Needs Qt6/KF6/libAeroQt dev files
# and cmake (the same things the AUR package builds with), and sudo to install.
# It replaces /usr/bin/explorer, so re-run it after the AUR package updates.
#
# Note: parts drawn by libAeroQt's shared stylesheet (shared with other ATP apps) aren't covered.
set -eu

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
say()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

for tool in git cmake python3; do have "$tool" || { warn "$tool is needed."; exit 1; }; done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/aerodark-explorer.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

if [ $# -ge 1 ]; then
  [ -f "$1/src/aero/palette.h" ] || { warn "$1 doesn't look like a linux-explorer folder."; exit 1; }
  say "Using the source in $1"
  cp -a "$1" "$WORK/explorer"
else
  repo="https://github.com/actuallyaridan/linux-explorer.git"
  tag="$(git ls-remote --tags --refs "$repo" 'v*' | sed 's#.*refs/tags/##' | sort -V | tail -n1)"
  say "Downloading linux-explorer ${tag:-(latest)}"
  git clone --quiet --depth 1 ${tag:+-b "$tag"} "$repo" "$WORK/explorer"
fi
rm -rf "$WORK/explorer/build"

say "Patching Explorer to follow light/dark"
mkdir -p "$WORK/explorer/assets/images/dark"
cp -a "$HERE/explorer-dark/." "$WORK/explorer/assets/images/dark/"
python3 - "$WORK/explorer" <<'PY'
import re, sys, os
root = sys.argv[1]
def rd(p): return open(os.path.join(root, p), encoding="utf-8").read()
def wr(p, s): open(os.path.join(root, p), "w", encoding="utf-8").write(s)

# 1. palette.h: constants become variables with a dark set swapped in at startup
DARK = {
    "Surface": "#141516", "FooterSurface": "#1C1D1F", "StripSurface": "#1E1F22", "NoticeSurface": "#3A3420",
    "Hairline": "#2B2D30", "FooterRule": "#2B2D30", "PaneRule": "#2B2D30", "StripRule": "#2B2D30",
    "NoticeRule": "#7A6420",
    "Text": "#ECECEC", "SoftText": "#DCDDDF", "MutedText": "#9A9DA2", "MutedHover": "#B4B7BB",
    "LinkText": "#5BB4FF", "LinkHover": "#8CCBFF", "CrumbHover": "#8CCBFF", "HeadingText": "#6CC4FF",
    "ArrowFill": "#C8C9CC", "CrumbArrow": "#9A9DA2",
    "GlassBorder": "#3C3F44", "GlassTop": "#4C4F54", "GlassBottom": "#222326", "GlassHover": "#2C5F8E",
    "GlassPressed": "#1D4A73", "FocusBorder": "#3DA2F0",
    "BannerStart": "#23303F", "BannerMid": "#1D4466", "BannerFar": "#2A5F8F", "BannerEnd": "#093D64",
}
s = rd("src/aero/palette.h")
names = re.findall(r'inline constexpr auto (\w+) = "#[0-9A-Fa-f]+";', s)
if len(names) < 20:
    sys.exit("palette.h looks different than expected")
s = re.sub(r'inline constexpr auto (\w+) = ("#[0-9A-Fa-f]+");', r'inline const char *\1 = \2;', s)
body = "".join(f'    {n} = "{DARK[n]}";\n' for n in names if n in DARK)
missing = [n for n in names if n not in DARK]
if missing:
    print("note: no dark value for", ", ".join(missing), "(kept light)")
s = s.replace("inline QColor rgb(const char *hex)",
              "// Aero Dark: swap in the dark set (called once at startup when the colour scheme is dark)\n"
              "inline void useDarkPalette()\n{\n" + body + "}\n\ninline QColor rgb(const char *hex)", 1)
if "useDarkPalette" not in s:
    sys.exit("couldn't add the dark palette to palette.h")
wr("src/aero/palette.h", s)

# 2. Assets.h: command bar artwork and the drive bar background get dark versions
s = rd("src/ui/Assets.h")
for n in ("CommandBar", "CommandHover", "CommandPress"):
    s, k = re.subn(r'inline constexpr auto %s = (":/win7/[^"]+");' % n, r'inline const char *%s = \1;' % n, s)
    if k != 1:
        sys.exit(f"Assets.h: {n} not found")
s = s.replace('QStringLiteral(":/win7/driveprogressbackground.png")',
              'QString::fromLatin1(DriveBackground)', 1)
s = s.replace("inline Aero::CapacityBarArt capacityBar()",
              'inline const char *DriveBackground = ":/win7/driveprogressbackground.png";\n'
              '// the address box\'s glass field (libAeroQt artwork)\n'
              'inline const char *EntryDir = ":/AeroQt/transpbg/entry/";\n\n'
              "// Aero Dark: dark command bar, blue pills and a dark drive bar\n"
              "inline void useDarkArt()\n{\n"
              '    CommandBar = ":/win7/dark/commandbar.png";\n'
              '    CommandHover = ":/win7/dark/commandhover.png";\n'
              '    CommandPress = ":/win7/dark/commandpress.png";\n'
              '    DriveBackground = ":/win7/dark/driveprogressbackground.png";\n'
              '    EntryDir = ":/win7/dark/entry/";\n'
              "}\n\ninline Aero::CapacityBarArt capacityBar()", 1)
if "useDarkArt" not in s or "DriveBackground)" not in s:
    sys.exit("Assets.h looks different than expected")
wr("src/ui/Assets.h", s)

# 3. resources: add the dark images
s = rd("src/ui/win7ui.qrc")
extra = "".join(f'        <file alias="dark/{f}">../../assets/images/dark/{f}</file>\n'
                for f in ("commandbar.png", "commandhover.png", "commandpress.png", "driveprogressbackground.png",
                          "entry/normal.png", "entry/hover.png", "entry/disabled.png"))
s = s.replace("    </qresource>", extra + "    </qresource>", 1)
wr("src/ui/win7ui.qrc", s)

# 4. MainWindow.cpp: the address box points at libAeroQt's light field artwork
s = rd("src/ui/MainWindow.cpp")
s, k = re.subn(r'(m_pathBox->setStyleSheet\()(\s*"#addressBox.*?")(\s*\);)',
               lambda m: m.group(1) + "QString::fromLatin1(" + m.group(2) + ")"
                         + '.replace(QLatin1String(":/AeroQt/transpbg/entry/"), QLatin1String(Explorer::Art::EntryDir))'
                         + m.group(3),
               s, count=1, flags=re.S)
if k != 1:
    print("note: address box stylesheet not found; it stays light")
else:
    wr("src/ui/MainWindow.cpp", s)

# 5. main.cpp: pick the set right after the application exists, before any window is built
s = rd("src/main.cpp")
s, k = re.subn(r"(\n\s*QApplication app\(argc, argv\);\n)",
               r"\1    // Aero Dark: follow a dark colour scheme\n"
               r"    if (QApplication::palette().color(QPalette::Window).lightness() < 128) {\n"
               r"        Aero::Palette::useDarkPalette();\n"
               r"        Explorer::Art::useDarkArt();\n"
               r"    }\n", s, count=1)
if k != 1:
    sys.exit("main.cpp: couldn't find where the application starts")
if '#include "aero/palette.h"' not in s:
    s = s.replace('#include "Assets.h"', '#include "Assets.h"\n#include "aero/palette.h"\n#include <QPalette>', 1)
wr("src/main.cpp", s)
print("patched")
PY

say "Building Explorer (this takes a few minutes)"
cd "$WORK/explorer"
gen=""; if have ninja; then gen="-G Ninja"; fi
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr $gen >/dev/null
cmake --build build
say "Installing it (asks for your password)"
SU=sudo; have sudo || SU=doas
"$SU" cmake --install build >/dev/null
say "Done. Close any open Explorer windows and start it again to see the dark look."
