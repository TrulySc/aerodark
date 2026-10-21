#!/usr/bin/env bash
# Aero Dark (VistaVG Black) for AeroThemePlasma — uninstaller.
# Switches back to AeroThemePlasma's own Global Theme if Aero Dark is active, then removes everything.
set -u

DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="$DATA/aerodark"
LNF_ID="aerodark"
ATP_LNF="authui7"
PLASMOID_ID="io.gitgud.wackyideas.SevenStart"

say()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

KREAD=kreadconfig6; have kreadconfig6 || KREAD=kreadconfig5
cur_lnf="$($KREAD --file kdeglobals --group KDE --key LookAndFeelPackage 2>/dev/null)"
cur_scheme="$($KREAD --file kdeglobals --group General --key ColorScheme 2>/dev/null)"
if [ "$cur_lnf" = "$LNF_ID" ] || [ "$cur_scheme" = "AeroDark" ]; then
  say "Switching back to AeroThemePlasma's Global Theme"
  if have plasma-apply-lookandfeel; then
    plasma-apply-lookandfeel -a "$ATP_LNF" >/dev/null 2>&1 \
      || warn "Couldn't switch automatically; pick 'Windows 7 style' in System Settings → Global Theme."
  else
    warn "Pick 'Windows 7 style' in System Settings → Global Theme."
  fi
fi

# put the light glass colour back, then stop the accent helper
if [ -x "$HOME/.local/bin/aerodark-sync" ]; then
  "$HOME/.local/bin/aerodark-sync" >/dev/null 2>&1
  "$HOME/.local/bin/aerodark-sync" --stop
  rm -f "$HOME/.local/bin/aerodark-sync" "$CONF/autostart/aerodark-sync.desktop"
fi

# an older version of the installer switched Kvantum itself to the dark theme
KVCONF="$CONF/Kvantum/kvantum.kvconfig"
[ -f "$KVCONF" ] && sed -i 's/^theme=Windows7AeroDark$/theme=Windows7Aero/' "$KVCONF"

say "Removing Aero Dark files"
rm -rf "$DATA/plasma/look-and-feel/$LNF_ID"
rm -f  "$DATA/color-schemes/AeroDark.colors"
rm -rf "$CONF/Kvantum/Windows7AeroDark"

DST="$DATA/plasma/plasmoids/$PLASMOID_ID"
restart=0
if [ -f "$DST/.aerodark" ]; then
  rm -rf "$DST"
  if [ -d "$STATE/SevenStart.backup" ]; then
    mv "$STATE/SevenStart.backup" "$DST"
    say "Put back your earlier custom Start menu copy"
  fi
  restart=1
fi
rm -rf "$STATE"

if [ "$restart" = 1 ]; then
  say "Restarting the Plasma shell"
  if have kquitapp6 && have kstart; then
    kquitapp6 plasmashell >/dev/null 2>&1; sleep 2; kstart plasmashell >/dev/null 2>&1 &
  else
    (plasmashell --replace >/dev/null 2>&1 &)
  fi
fi
say "Done. Restart open apps to see the light style again."
