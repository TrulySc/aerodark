#!/usr/bin/env bash
# Aero Dark — let apps built on libAeroQt (linux-explorer and other AeroShell apps) use the dark style.
#
# libAeroQt replaces an app's widget style with its own, which is built on top of Kvantum but
# hard-codes the *light* Kvantum style ("kvantum"), and paints a few things itself (the yellow
# notice bar, the details strip at the bottom of Explorer, glass text fields). This patches it so
# that whenever your application style is "kvantum-dark" (which Aero Dark sets) those apps get the
# dark Windows7AeroDark widgets and dark versions of those parts. With ATP's light theme nothing
# changes.
#
#   ./dark-libaeroqt.sh [path to a libaero-qt source folder]
#
# Without a path it downloads the source from gitgud.io. Needs Qt6/KF6 dev files and cmake, and
# sudo to install. Re-run after libaero-qt updates. Restart apps after switching theme.
set -eu

say()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

for tool in git cmake python3; do have "$tool" || { warn "$tool is needed."; exit 1; }; done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/aerodark-libaeroqt.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

if [ $# -ge 1 ]; then
  [ -f "$1/src/AeroQt/private/customqstyle.cpp" ] || { warn "$1 doesn't look like a libaero-qt folder."; exit 1; }
  say "Using the source in $1"
  cp -a "$1" "$WORK/aeroqt"
else
  say "Downloading libaero-qt"
  git clone --quiet --depth 1 https://gitgud.io/atmk/libaero-qt.git "$WORK/aeroqt"
fi
rm -rf "$WORK/aeroqt/build"

say "Patching libAeroQt to follow Kvantum's dark style"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$WORK/aeroqt/src/resources/dark"
cp -a "$HERE/libaeroqt-dark/." "$WORK/aeroqt/src/resources/dark/"
python3 - "$WORK/aeroqt/src" <<'PY'
import os, sys
src = sys.argv[1]
p = os.path.join(src, "AeroQt/private/customqstyle.cpp")
s = open(p, encoding="utf-8").read()
if "aeroDarkBaseStyle" in s:
    print("already patched"); sys.exit(0)

def swap(old, new):
    global s
    if s.count(old) != 1:
        sys.exit(f"customqstyle.cpp: expected text not found once: {old!r}")
    s = s.replace(old, new)

helper = """
#include <KSharedConfig>
#include <KConfigGroup>

// Aero Dark: build on Kvantum's dark variant when that is the selected application style
static QString aeroDarkBaseStyle()
{
    const QString style = KSharedConfig::openConfig(QStringLiteral("kdeglobals"))
                              ->group(QStringLiteral("KDE"))
                              .readEntry("widgetStyle", QString());
    return style.compare(QLatin1String("kvantum-dark"), Qt::CaseInsensitive) == 0
        ? QStringLiteral("kvantum-dark")
        : QStringLiteral("kvantum");
}
static bool aeroDark()
{
    static const bool dark = aeroDarkBaseStyle() == QLatin1String("kvantum-dark");
    return dark;
}
"""
swap("using namespace Aero::Private;", "using namespace Aero::Private;\n" + helper)
# 1. the widget style itself
swap(': QProxyStyle("kvantum")', ": QProxyStyle(aeroDarkBaseStyle())")
# 2. the details/info strip artwork
swap('QImage(":/AeroQt/infostrip.9.png")',
     'QImage(aeroDark() ? QStringLiteral(":/AeroQt/dark/infostrip.9.png") : QStringLiteral(":/AeroQt/infostrip.9.png"))')
# 3. the yellow notice bar
swap('p.fillRect(w->rect(), QColor("#FFFFE1"));',
     'p.fillRect(w->rect(), QColor(aeroDark() ? "#3A3420" : "#FFFFE1"));')
swap('p.setPen(QColor("#E3C86B"));', 'p.setPen(QColor(aeroDark() ? "#7A6420" : "#E3C86B"));')
# 4. the shared stylesheet: dark field artwork
swap("qss = f.readAll();",
     'qss = f.readAll();\n        if (aeroDark())\n'
     '            qss.replace(QLatin1String(":/AeroQt/transpbg/entry/"), QLatin1String(":/AeroQt/dark/transpbg/entry/"));')
open(p, "w", encoding="utf-8").write(s)

q = os.path.join(src, "resources/res.qrc")
r = open(q, encoding="utf-8").read()
extra = "".join(f"        <file>dark/{f}</file>\n" for f in
                ("infostrip.9.png", "transpbg/entry/normal.png", "transpbg/entry/hover.png", "transpbg/entry/disabled.png"))
if "dark/infostrip.9.png" not in r:
    r = r.replace("    </qresource>", extra + "    </qresource>", 1)
open(q, "w", encoding="utf-8").write(r)
print("patched")
PY

say "Building libAeroQt"
cd "$WORK/aeroqt"
gen=""; if have ninja; then gen="-G Ninja"; fi
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr $gen >/dev/null
cmake --build build
say "Installing it (asks for your password)"
SU=sudo; have sudo || SU=doas
"$SU" cmake --install build >/dev/null
say "Done. Restart Explorer (and other libAeroQt apps) to pick up the dark style."
