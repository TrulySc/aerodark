#!/usr/bin/env bash
# Aero Dark for AeroThemePlasma — installer
# Installs per-user only (nothing under /usr is touched), and remembers your
# previous settings so ./uninstall.sh can put them back.
#
#   ./install.sh               install everything and apply it
#   ./install.sh --no-startmenu   skip darkening the Start menu's left pane
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="$DATA/aerodark"
PLASMOID_ID="io.gitgud.wackyideas.SevenStart"
DO_STARTMENU=1

for arg in "$@"; do
  case "$arg" in
    --no-startmenu) DO_STARTMENU=0 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

say()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

KREAD=kreadconfig6;  have kreadconfig6  || KREAD=kreadconfig5
mkdir -p "$STATE"

# ---- remember current settings (only on first install) ----------------------
if [ ! -f "$STATE/previous" ]; then
  prev_scheme="$($KREAD --file kdeglobals --group General --key ColorScheme 2>/dev/null)"
  prev_kv="$($KREAD --file "$CONF/Kvantum/kvantum.kvconfig" --group General --key theme 2>/dev/null)"
  {
    echo "PREV_SCHEME=${prev_scheme:-Aero}"
    echo "PREV_KVANTUM=${prev_kv:-Windows7Aero}"
  } > "$STATE/previous"
fi

# ---- 1. colour scheme --------------------------------------------------------
say "Installing the Aero Dark colour scheme"
mkdir -p "$DATA/color-schemes"
cp -f "$HERE/color-schemes/AeroDark.colors" "$DATA/color-schemes/"

# ---- 2. Kvantum widget theme --------------------------------------------------
say "Installing the Windows7AeroDark Kvantum theme"
mkdir -p "$CONF/Kvantum/Windows7AeroDark"
cp -f "$HERE/kvantum/Windows7AeroDark/"* "$CONF/Kvantum/Windows7AeroDark/"

# ---- 3. Start menu left pane --------------------------------------------------
replace_literal() { # file old new -> prints number of hits
  local f="$1" old="$2" new="$3" n
  n="$(grep -cF -- "$old" "$f" 2>/dev/null || true)"
  [ "${n:-0}" -gt 0 ] || { echo 0; return; }
  if have perl; then
    OLD="$old" NEW="$new" perl -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/g' "$f"
  elif have python3; then
    OLD="$old" NEW="$new" python3 - "$f" <<'PY'
import os, sys
p = sys.argv[1]; s = open(p, encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(s.replace(os.environ['OLD'], os.environ['NEW']))
PY
  else
    echo 0; return
  fi
  echo "$n"
}

if [ "$DO_STARTMENU" = 1 ]; then
  say "Darkening the Start menu (a private copy in your home folder)"
  SRC=""
  for d in /usr/share /usr/local/share $(echo "${XDG_DATA_DIRS:-}" | tr ':' ' '); do
    if [ -f "$d/plasma/plasmoids/$PLASMOID_ID/metadata.json" ]; then SRC="$d/plasma/plasmoids/$PLASMOID_ID"; break; fi
  done
  DST="$DATA/plasma/plasmoids/$PLASMOID_ID"
  if [ -z "$SRC" ]; then
    warn "Couldn't find the installed Seven Start menu — skipping this step."
  else
    if [ -d "$DST" ] && [ ! -f "$DST/.aerodark" ]; then
      warn "You already had a custom copy of the Start menu; backing it up to $STATE/SevenStart.backup"
      rm -rf "$STATE/SevenStart.backup"; mv "$DST" "$STATE/SevenStart.backup"
    fi
    rm -rf "$DST"; mkdir -p "$(dirname "$DST")"
    cp -a "$SRC" "$DST"
    touch "$DST/.aerodark"
    cp -f "$HERE/startmenu/svgs/"*.svg "$DST/contents/ui/svgs/"
    missed=0
    while IFS=$'\t' read -r file old new; do
      case "$file" in ''|\#*) continue ;; esac
      hits="$(replace_literal "$DST/contents/ui/$file" "$old" "$new")"
      [ "$hits" -gt 0 ] || { missed=$((missed+1)); warn "  not found in $file: $old"; }
    done < "$HERE/startmenu/replacements.txt"
    [ "$missed" = 0 ] || warn "$missed Start menu colour(s) weren't found — your AeroThemePlasma version may differ; the rest still applied."
  fi
fi

# ---- 4. apply ---------------------------------------------------------------
say "Applying"
if have plasma-apply-colorscheme; then
  plasma-apply-colorscheme AeroDark >/dev/null || warn "Couldn't apply the colour scheme; pick 'Aero Dark' in System Settings → Colors."
else
  warn "plasma-apply-colorscheme not found; pick 'Aero Dark' in System Settings → Colors."
fi
if have kvantummanager; then
  kvantummanager --set Windows7AeroDark >/dev/null 2>&1 || warn "Couldn't switch Kvantum; choose Windows7AeroDark in Kvantum Manager."
else
  mkdir -p "$CONF/Kvantum"
  if [ -f "$CONF/Kvantum/kvantum.kvconfig" ] && grep -q '^theme=' "$CONF/Kvantum/kvantum.kvconfig"; then
    sed -i 's/^theme=.*/theme=Windows7AeroDark/' "$CONF/Kvantum/kvantum.kvconfig"
  else
    printf '[General]\ntheme=Windows7AeroDark\n' >> "$CONF/Kvantum/kvantum.kvconfig"
  fi
fi

if [ "$DO_STARTMENU" = 1 ] && [ -n "${SRC:-}" ]; then
  say "Restarting the Plasma shell so the Start menu picks up its new colours"
  if have kquitapp6 && have kstart; then
    kquitapp6 plasmashell >/dev/null 2>&1; sleep 2; kstart plasmashell >/dev/null 2>&1 &
  else
    (plasmashell --replace >/dev/null 2>&1 &)
  fi
fi

say "Done. Apps that were already open need to be restarted to go dark."
say "If you update AeroThemePlasma later, run ./install.sh again so the Start menu copy stays in sync."
