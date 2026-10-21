#!/usr/bin/env bash
# Aero Dark for AeroThemePlasma — uninstaller: removes Aero Dark and restores your previous look.
set -u

DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="$DATA/aerodark"
PLASMOID_ID="io.gitgud.wackyideas.SevenStart"

say()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

PREV_SCHEME=Aero
PREV_KVANTUM=Windows7Aero
# shellcheck disable=SC1091
[ -f "$STATE/previous" ] && . "$STATE/previous"

say "Restoring colour scheme: $PREV_SCHEME"
have plasma-apply-colorscheme && plasma-apply-colorscheme "$PREV_SCHEME" >/dev/null 2>&1 \
  || warn "Pick your colour scheme in System Settings → Colors."

say "Restoring Kvantum theme: $PREV_KVANTUM"
if have kvantummanager; then
  kvantummanager --set "$PREV_KVANTUM" >/dev/null 2>&1
elif [ -f "$CONF/Kvantum/kvantum.kvconfig" ]; then
  sed -i "s/^theme=.*/theme=$PREV_KVANTUM/" "$CONF/Kvantum/kvantum.kvconfig"
fi

say "Removing Aero Dark files"
rm -f  "$DATA/color-schemes/AeroDark.colors"
rm -rf "$CONF/Kvantum/Windows7AeroDark"

DST="$DATA/plasma/plasmoids/$PLASMOID_ID"
restarted=0
if [ -f "$DST/.aerodark" ]; then
  rm -rf "$DST"
  if [ -d "$STATE/SevenStart.backup" ]; then
    mv "$STATE/SevenStart.backup" "$DST"
    say "Put back your earlier custom Start menu copy"
  fi
  restarted=1
fi
rm -rf "$STATE"

if [ "$restarted" = 1 ]; then
  say "Restarting the Plasma shell"
  if have kquitapp6 && have kstart; then
    kquitapp6 plasmashell >/dev/null 2>&1; sleep 2; kstart plasmashell >/dev/null 2>&1 &
  else
    (plasmashell --replace >/dev/null 2>&1 &)
  fi
fi
say "Done. Restart open apps to see the light theme again."
