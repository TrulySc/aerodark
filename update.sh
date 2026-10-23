#!/usr/bin/env bash
# Aero Dark — apply a new AeroDark.tar.gz in one go, then save it to GitHub.
#
#   ~/Downloads/aerodark-repo/update.sh                 # newest AeroDark*.tar.gz in ~/Downloads
#   ~/Downloads/aerodark-repo/update.sh path/to/AeroDark.tar.gz
#
# What it does:
#   1. unpacks the archive into this repo (files that were removed from the package are removed too)
#   2. runs install.sh (desktop theme, applets, helpers)
#   3. installs the Discord themes and icon tools, and regenerates AeroIcons/AeroEmoji
#   4. re-runs the rebuild scripts in extras/ (notifications, UAC prompt, …) only if they changed
#      since the last update — those compile code and ask for your password
#   5. commits everything and pushes it to GitHub
#
# Options: --no-extras (skip step 4)   --no-push (commit but don't push)   --no-git (skip step 5)
set -eu

say()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

# This script is replaced by the archive it unpacks, so run from a temporary copy.
if [ -z "${AERODARK_UPDATE_COPY:-}" ]; then
  tmp="$(mktemp "${TMPDIR:-/tmp}/aerodark-update.XXXXXX")"
  cp "$0" "$tmp"; chmod +x "$tmp"
  AERODARK_UPDATE_COPY="$tmp" AERODARK_REPO="$(cd "$(dirname "$0")" && pwd)" exec "$tmp" "$@"
fi
trap 'rm -f "$AERODARK_UPDATE_COPY"' EXIT
REPO="$AERODARK_REPO"

EXTRAS=1 PUSH=1 GIT=1 ARCHIVE=""
for a in "$@"; do
  case "$a" in
    --no-extras) EXTRAS=0 ;;
    --no-push)   PUSH=0 ;;
    --no-git)    GIT=0 ;;
    -h|--help)   sed -n '2,17p' "$AERODARK_UPDATE_COPY" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)           ARCHIVE="$a" ;;
  esac
done

DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="$DATA/aerodark"; mkdir -p "$STATE"

# ---- 1. unpack ------------------------------------------------------------------------
if [ -z "$ARCHIVE" ]; then
  # newest download, including browser-renamed copies like "AeroDark (1).tar.gz"
  ARCHIVE="$(ls -t "$HOME"/Downloads/AeroDark*.tar.gz 2>/dev/null | head -n1 || true)"
fi
[ -n "$ARCHIVE" ] && [ -f "$ARCHIVE" ] || { warn "No AeroDark*.tar.gz found in ~/Downloads (or pass its path)."; exit 1; }
say "Unpacking $(basename "$ARCHIVE") into $REPO"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/aerodark-unpack.XXXXXX")"
trap 'rm -f "$AERODARK_UPDATE_COPY"; rm -rf "$WORK"' EXIT
tar xzf "$ARCHIVE" -C "$WORK"
SRC="$WORK/AeroDark"; [ -d "$SRC" ] || SRC="$WORK"
[ -f "$SRC/install.sh" ] || { warn "That archive doesn't look like Aero Dark."; exit 1; }

# remember the extras as they were, to know which changed
old_sums="$(cd "$REPO" 2>/dev/null && sha256sum extras/*.sh 2>/dev/null || true)"

if have rsync; then
  rsync -a --delete --exclude '.git/' "$SRC/" "$REPO/"
else
  # no rsync: copy over, then remove files the new package no longer has
  (cd "$REPO" && git ls-files 2>/dev/null) | while IFS= read -r f; do
    [ -e "$SRC/$f" ] || rm -f "$REPO/$f"
  done
  cp -a "$SRC/." "$REPO/"
fi
chmod +x "$REPO"/*.sh "$REPO"/extras/*.sh "$REPO"/discord/build.sh \
         "$REPO"/discord/icons/aerodark-discord-icons 2>/dev/null || true

# ---- 2. desktop theme -----------------------------------------------------------------
say "Running install.sh"
(cd "$REPO" && ./install.sh)

# ---- 3. Discord -----------------------------------------------------------------------
if [ -d "$CONF/vesktop" ] || [ -d "$CONF/Vencord" ]; then
  for d in "$CONF/vesktop/themes" "$CONF/Vencord/themes"; do
    [ -d "$(dirname "$d")" ] || continue
    mkdir -p "$d"
    cp -f "$REPO"/discord/AeroLight.theme.css "$REPO"/discord/AeroDark.theme.css "$d/"
  done
  say "Updated the Discord themes"
  mkdir -p "$HOME/.local/bin" "$DATA/aerodark/discord"
  cp -f "$REPO/discord/icons/aerodark-discord-icons" "$HOME/.local/bin/"
  chmod +x "$HOME/.local/bin/aerodark-discord-icons"
  for f in icon-map.json emoji-list.json import-redrawn-icons.py redraw/redraw-pages.json; do
    [ -f "$REPO/discord/icons/$f" ] && cp -f "$REPO/discord/icons/$f" "$DATA/aerodark/discord/"
  done
  "$HOME/.local/bin/aerodark-discord-icons" || warn "Couldn't regenerate the Discord icons."
  say "Restart Vesktop (or toggle the themes off and on) to see the Discord changes."
fi

# ---- 4. rebuild scripts that changed ----------------------------------------------------
# Ask for the password once, up front, and keep it fresh — otherwise each rebuild prompts again
# in the middle of build output, which is easy to mistype (and too many misses lock sudo).
if [ "$EXTRAS" = 1 ] && have sudo; then
  say "The rebuild steps install files system-wide; enter your password once:"
  if sudo -v; then
    ( while sleep 50; do sudo -n true 2>/dev/null || exit; kill -0 "$$" 2>/dev/null || exit; done ) &
    KEEPALIVE=$!
    trap 'rm -f "$AERODARK_UPDATE_COPY"; rm -rf "$WORK"; kill "$KEEPALIVE" 2>/dev/null || true' EXIT
  else
    warn "sudo didn't accept the password; skipping the rebuild steps (see: faillock --user $USER)."
    EXTRAS=0
  fi
fi
if [ "$EXTRAS" = 1 ]; then
  for s in "$REPO"/extras/dark-*.sh; do
    [ -f "$s" ] || continue
    name="extras/$(basename "$s")"
    new="$(sha256sum "$s" | cut -d' ' -f1)"
    applied="$(cat "$STATE/applied-$(basename "$s")" 2>/dev/null || true)"
    was="$(printf '%s\n' "$old_sums" | awk -v n="$name" '$2 == n { print $1 }')"
    # run it if it changed in this update, or it's never been run by this script
    if [ "$new" != "$applied" ] && { [ "$new" != "$was" ] || [ -z "$applied" ]; }; then
      say "Running $name (it changed)"
      if (cd "$REPO/extras" && "./$(basename "$s")"); then
        echo "$new" > "$STATE/applied-$(basename "$s")"
      else
        warn "$name failed — the rest of the update still applied. Run it again later with: $s"
      fi
    fi
  done
fi

# ---- 5. GitHub --------------------------------------------------------------------------
if [ "$GIT" = 1 ]; then
  cd "$REPO"
  if [ ! -d .git ]; then
    warn "$REPO isn't a git repository; skipping GitHub."
  else
    git add -A
    if git diff --cached --quiet; then
      say "Nothing new to commit."
    else
      changed="$(git diff --cached --name-only | cut -d/ -f1 | sort -u | tr '\n' ' ')"
      git commit -q -m "Update $(date +%Y-%m-%d): ${changed% }"
      say "Committed: $(git log -1 --pretty=%s)"
    fi
    if [ "$PUSH" = 1 ] && git remote get-url origin >/dev/null 2>&1; then
      if git push -q origin HEAD; then say "Pushed to $(git remote get-url origin)"
      else warn "Push failed — check your SSH key or network, then run: cd $REPO && git push"; fi
    fi
  fi
fi
say "Update done."
