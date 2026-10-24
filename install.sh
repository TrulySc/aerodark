#!/usr/bin/env bash
# Aero Dark (VistaVG Black) for AeroThemePlasma — installer
#
# Adds an "Aero Dark" Global Theme next to AeroThemePlasma's own one, so you can switch
# between light and dark in System Settings → Global Theme. Per-user only: nothing under
# /usr is touched and no sudo is needed. Safe to run again (e.g. after updating ATP).
#
#   ./install.sh                install and switch to Aero Dark
#   ./install.sh --no-apply     install only; switch later in System Settings
#   ./install.sh --no-startmenu leave the Start menu untouched
#   ./install.sh --no-accent    don't switch the taskbar/title-bar glass colour automatically
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="$DATA/aerodark"
LNF_ID="aerodark"
ATP_LNF="authui7"
PLASMOID_ID="io.gitgud.wackyideas.SevenStart"
TRAY_ID="io.gitgud.wackyideas.systemtray"
ATP_STYLE="Seven-Black"
DARK_STYLE="Seven-Black-Dark"
DO_STARTMENU=1
DO_APPLY=1
DO_ACCENT=1

for arg in "$@"; do
  case "$arg" in
    --no-startmenu) DO_STARTMENU=0 ;;
    --no-apply) DO_APPLY=0 ;;
    --no-accent) DO_ACCENT=0 ;;
    -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

say()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

find_system() { # find_system <relative path under share/> -> first installed copy
  local d
  for d in /usr/share /usr/local/share $(echo "${XDG_DATA_DIRS:-}" | tr ':' ' '); do
    [ -e "$d/$1" ] && { echo "$d/$1"; return 0; }
  done
  return 1
}

mkdir -p "$STATE"

# ---- 1. colour scheme -------------------------------------------------------------
say "Installing the Aero Dark colour scheme"
mkdir -p "$DATA/color-schemes"
cp -f "$HERE/color-schemes/AeroDark.colors" "$DATA/color-schemes/"

# ---- 2. Kvantum dark variant ---------------------------------------------------------
# Kvantum's "kvantum-dark" application style automatically uses <current theme>Dark,
# so this folder is picked up whenever the dark style is active, and the light
# Windows7Aero theme stays in charge otherwise.
say "Installing the Windows7AeroDark Kvantum variant"
mkdir -p "$CONF/Kvantum/Windows7AeroDark"
cp -f "$HERE/kvantum/Windows7AeroDark/"* "$CONF/Kvantum/Windows7AeroDark/"

KVCONF="$CONF/Kvantum/kvantum.kvconfig"
cur_kv="$(sed -n 's/^theme=//p' "$KVCONF" 2>/dev/null | head -n1)"
if [ "$cur_kv" = "Windows7AeroDark" ]; then
  # an earlier version of this installer switched Kvantum itself to the dark theme; undo that
  sed -i 's/^theme=.*/theme=Windows7Aero/' "$KVCONF"
elif [ -n "$cur_kv" ] && [ "$cur_kv" != "Windows7Aero" ]; then
  warn "Kvantum is set to '$cur_kv', not Windows7Aero — the dark style will only work with Windows7Aero."
fi

# ---- 3. dark Plasma style (popups, notifications, tooltips) --------------------------
say "Installing the '$DARK_STYLE' Plasma style"
STYLE_DST="$DATA/plasma/desktoptheme/$DARK_STYLE"
rm -rf "$STYLE_DST"; mkdir -p "$(dirname "$STYLE_DST")"
if STYLE_SRC="$(find_system "plasma/desktoptheme/$ATP_STYLE")"; then
  # built from AeroThemePlasma's own Seven-Black, so the taskbar, glass and icons stay identical;
  # only the popup bodies, tooltips, fields, buttons, sliders and list highlights are darkened
  cp -a "$STYLE_SRC" "$STYLE_DST"
  (cd "$HERE/plasma-style/files" && find . -type f) | while read -r f; do
    mkdir -p "$STYLE_DST/$(dirname "$f")"; cp -f "$HERE/plasma-style/files/$f" "$STYLE_DST/$f"
  done
  cp -f "$HERE/plasma-style/colors" "$STYLE_DST/colors"
  if have python3; then
    python3 - "$STYLE_DST/metadata.json" <<'PY'
import json, sys
p = sys.argv[1]; m = json.load(open(p))
m["KPlugin"]["Id"] = "Seven-Black-Dark"
m["KPlugin"]["Name"] = "Seven Black Dark (Aero Dark)"
m["KPlugin"]["Description"] = "AeroThemePlasma's Seven Black with dark popups, for Aero Dark"
json.dump(m, open(p, "w"), indent=4)
PY
  else
    sed -i -e 's/"Id": *"Seven-Black"/"Id": "Seven-Black-Dark"/' -e 's/"Name": *"Seven Black"/"Name": "Seven Black Dark (Aero Dark)"/' "$STYLE_DST/metadata.json"
  fi
  rm -rf "$HOME/.cache/plasma_theme_${DARK_STYLE}"* "$HOME/.cache/plasma-svgelements-${DARK_STYLE}"* 2>/dev/null
  STYLE_OK=1
else
  warn "AeroThemePlasma's Plasma style ($ATP_STYLE) wasn't found; popups will stay light."
  STYLE_OK=0
fi

# ---- 4. Global Theme -----------------------------------------------------------------
say "Installing the 'Aero Dark' Global Theme"
LNF_DST="$DATA/plasma/look-and-feel/$LNF_ID"
rm -rf "$LNF_DST"; mkdir -p "$(dirname "$LNF_DST")"
if ATP_SRC="$(find_system "plasma/look-and-feel/$ATP_LNF")"; then
  # start from AeroThemePlasma's own Global Theme so the splash, logout screen etc. stay Windows 7
  cp -a "$ATP_SRC" "$LNF_DST"
else
  warn "AeroThemePlasma's Global Theme ($ATP_LNF) wasn't found; installing a minimal one."
  mkdir -p "$LNF_DST/contents"
fi
cp -f "$HERE/global-theme/metadata.json" "$LNF_DST/metadata.json"
if [ -f "$LNF_DST/contents/defaults" ]; then
  # keep everything ATP's theme sets (icons, cursors, window decoration, splash …), only swap colours + style
  sed -i -e 's/^ColorScheme=.*/ColorScheme=AeroDark/' -e 's/^widgetStyle=.*/widgetStyle=kvantum-dark/' \
    "$LNF_DST/contents/defaults"
  grep -q '^ColorScheme=AeroDark' "$LNF_DST/contents/defaults" && grep -q '^widgetStyle=kvantum-dark' "$LNF_DST/contents/defaults" \
    || cp -f "$HERE/global-theme/contents/defaults" "$LNF_DST/contents/defaults"
else
  cp -f "$HERE/global-theme/contents/defaults" "$LNF_DST/contents/defaults"
fi
if [ "$STYLE_OK" = 1 ]; then
  if grep -q '^\[plasmarc\]\[Theme\]' "$LNF_DST/contents/defaults"; then
    awk -v st="$DARK_STYLE" '/^\[/ { sec = $0 } sec == "[plasmarc][Theme]" && /^name=/ { print "name=" st; next } { print }' \
      "$LNF_DST/contents/defaults" > "$LNF_DST/contents/defaults.tmp" && mv "$LNF_DST/contents/defaults.tmp" "$LNF_DST/contents/defaults"
  else
    printf '\n[plasmarc][Theme]\nname=%s\n' "$DARK_STYLE" >> "$LNF_DST/contents/defaults"
  fi
fi
# KDE's "Dark Mode" quick toggle (Display popup) and day/night switching use these two themes
KWRITE=kwriteconfig6; have kwriteconfig6 || KWRITE=kwriteconfig5
if have "$KWRITE"; then
  "$KWRITE" --file kdeglobals --group KDE --key DefaultDarkLookAndFeel "$LNF_ID"
  "$KWRITE" --file kdeglobals --group KDE --key DefaultLightLookAndFeel "$ATP_LNF"
fi
mkdir -p "$LNF_DST/contents/previews"
cp -f "$HERE/global-theme/contents/previews/"* "$LNF_DST/contents/previews/"

# ---- 5. Start menu + tray popups: follow light/dark automatically ---------------------------------
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

add_dark_flag() { # declare `adDark` on the file's root object: true when the colour scheme is dark
  local f="$1"
  grep -q 'property bool adDark' "$f" && return 0
  awk 'done != 1 && /^[A-Z][A-Za-z0-9_.]* *\{ *$/ {
         print
         print "    property SystemPalette adPal: SystemPalette { colorGroup: SystemPalette.Active } // Aero Dark"
         print "    readonly property bool adDark: adPal.window.hslLightness < 0.5 // Aero Dark"
         done = 1; next }
       { print }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  grep -q 'property bool adDark' "$f"
}

patch_plasmoid() { # patch_plasmoid <plasmoid id> <label> <replacements file> [dark svg dir]
  local id="$1" label="$2" repl="$3" svgs="${4:-}" src dst missed=0 file old new hits
  dst="$DATA/plasma/plasmoids/$id"
  if ! src="$(find_system "plasma/plasmoids/$id")"; then
    warn "Couldn't find the installed $label ($id) — skipping it."
    return 1
  fi
  if [ -d "$dst" ] && [ ! -f "$dst/.aerodark" ]; then
    warn "You already had a custom copy of the $label; backing it up to $STATE/$id.backup"
    rm -rf "$STATE/$id.backup"; mv "$dst" "$STATE/$id.backup"
  fi
  rm -rf "$dst"; mkdir -p "$(dirname "$dst")"
  cp -a "$src" "$dst"
  touch "$dst/.aerodark"
  if [ -n "$svgs" ]; then
    mkdir -p "$dst/contents/ui/svgs/aerodark"
    cp -f "$svgs/"*.svg "$dst/contents/ui/svgs/aerodark/"
  fi
  for file in $(grep -v '^#' "$repl" | cut -f1 | sort -u); do
    add_dark_flag "$dst/contents/ui/$file" || { missed=$((missed+1)); warn "  couldn't prepare $file"; }
  done
  while IFS=$'\t' read -r file old new; do
    case "$file" in ''|\#*) continue ;; esac
    hits="$(replace_literal "$dst/contents/ui/$file" "$old" "$new")"
    [ "$hits" -gt 0 ] || { missed=$((missed+1)); warn "  not found in $file: $old"; }
  done < "$repl"
  [ "$missed" = 0 ] || warn "$missed $label change(s) didn't apply — your AeroThemePlasma version may differ; the rest still applied."
  return 0
}

SHELL_RESTART=0
if [ "$DO_STARTMENU" = 1 ]; then
  say "Teaching the Start menu to follow light/dark (a private copy in your home folder)"
  patch_plasmoid "$PLASMOID_ID" "Start menu" "$HERE/startmenu/replacements.txt" "$HERE/startmenu/svgs" && SHELL_RESTART=1
fi
say "Teaching the tray, network, volume, clock and battery popups to follow light/dark, and fixing the taskbar order (private copies)"
for repl in "$HERE/applets/"*.txt; do
  id="$(basename "$repl" .txt)"
  patch_plasmoid "$id" "$id" "$repl" && SHELL_RESTART=1
done
# volume applet: a light copy of its dropdown arrows for dark mode (made from the installed artwork)
VOLUI="$DATA/plasma/plasmoids/io.gitgud.wackyideas.volume/contents/ui"
if [ -f "$VOLUI/svgs/control.svg" ]; then
  mkdir -p "$VOLUI/svgs/aerodark"
  python3 - "$VOLUI/svgs/control.svg" "$VOLUI/svgs/aerodark/control.svg" <<'PY' || warn "Couldn't make the light volume arrows."
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
# the dropdown arrow is a plain black path with id="dropdown"
s, n = re.subn(r'(<path\b[^>]*?style="fill:)#000000([^"]*"[^>]*?id="dropdown")', r'\1#d8dade\2', s, flags=re.S)
if not n:
    s, n = re.subn(r'(<path\b(?:(?!/>).)*?id="dropdown"(?:(?!/>).)*?)fill:#000000', r'\1fill:#d8dade', s, flags=re.S)
open(sys.argv[2], "w", encoding="utf-8").write(s)
PY
fi

# ---- 6. glass accent follows light/dark -------------------------------------------
if [ "$DO_ACCENT" = 1 ]; then
  say "Installing the helper that switches the taskbar/title-bar glass between your colour and black"
  BIN="$HOME/.local/bin"; mkdir -p "$BIN" "$CONF/autostart"
  cp -f "$HERE/helper/aerodark-sync" "$BIN/aerodark-sync"; chmod +x "$BIN/aerodark-sync"
  cat > "$CONF/autostart/aerodark-sync.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Aero Dark accent sync
Comment=Switches AeroThemePlasma's glass colour to black while Aero Dark is active
Exec=$BIN/aerodark-sync --watch
X-KDE-autostart-phase=2
NoDisplay=true
EOF
  "$BIN/aerodark-sync" --stop
  if have setsid; then (setsid "$BIN/aerodark-sync" --watch >/dev/null 2>&1 &); else (nohup "$BIN/aerodark-sync" --watch >/dev/null 2>&1 &); fi
  if ! grep -qE '^(AccentColorGroup|AeroIntensity|CustomColor)=' "$CONF/kwinrc" 2>/dev/null; then
    warn "AeroThemePlasma hasn't saved a glass colour yet. Open its window colour page once and click"
    warn "Save Changes with your normal colour; after that the glass switches automatically."
  fi
fi

# ---- 6b. Discord (Vesktop) uses your Plasma icon theme -----------------------------
if have python3; then
  say "Installing aerodark-discord-icons (Discord uses your Plasma icon theme)"
  BIN="$HOME/.local/bin"; mkdir -p "$BIN" "$DATA/aerodark/discord"
  cp -f "$HERE/discord/icons/aerodark-discord-icons" "$BIN/aerodark-discord-icons"
  chmod +x "$BIN/aerodark-discord-icons"
  cp -f "$HERE/discord/icons/icon-map.json" "$HERE/discord/icons/redraw/redraw-pages.json" \
        "$HERE/discord/icons/import-redrawn-icons.py" "$HERE/discord/icons/import-emoticons.py" "$HERE/discord/icons/emoji-list.json" \
        "$DATA/aerodark/discord/"
  if [ -d "$CONF/vesktop" ]; then
    "$BIN/aerodark-discord-icons" || warn "Couldn't generate the Discord icon theme."
  fi
fi

# ---- 7. apply ------------------------------------------------------------------------
if [ "$DO_APPLY" = 1 ]; then
  if have plasma-apply-lookandfeel; then
    say "Switching to Aero Dark"
    plasma-apply-lookandfeel -a "$LNF_ID" >/dev/null 2>&1 \
      || warn "Couldn't switch automatically; pick 'Aero Dark' in System Settings → Global Theme."
    [ "$DO_ACCENT" = 1 ] && "$HOME/.local/bin/aerodark-sync" >/dev/null 2>&1
  else
    warn "plasma-apply-lookandfeel not found; pick 'Aero Dark' in System Settings → Global Theme."
  fi
fi

if [ "$SHELL_RESTART" = 1 ]; then
  say "Restarting the Plasma shell so it loads the new Start menu"
  if have kquitapp6 && have kstart; then
    kquitapp6 plasmashell >/dev/null 2>&1; sleep 2; kstart plasmashell >/dev/null 2>&1 &
  else
    (plasmashell --replace >/dev/null 2>&1 &)
  fi
fi

say "Done. Switch any time in System Settings → Global Theme: 'Aero Dark' or AeroThemePlasma's 'Windows 7 style'."
say "Apps that were already open need a restart to change style. Run ./install.sh again after updating AeroThemePlasma."
