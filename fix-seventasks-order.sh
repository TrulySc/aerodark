#!/usr/bin/env bash
# Fix for AeroThemePlasma's SevenTasks taskbar:
#   * pinned programs keep their place when you start them (instead of jumping to the end)
#   * the order you drag pinned items into is kept, including after logging out
#
# Cause: SevenTasks turns on KDE's "launch in place" sorting but forces `separateLaunchers: false`,
# and KDE's task model only honours launch-in-place when separateLaunchers is on. This restores
# the same logic KDE's own Icons-only Task Manager uses.
#
# Works on a private copy in ~/.local/share (nothing under /usr is touched, no sudo).
#   ./fix-seventasks-order.sh          apply (run again after updating AeroThemePlasma)
#   ./fix-seventasks-order.sh --undo   go back to the stock SevenTasks
set -u

ID="io.gitgud.wackyideas.seventasks"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
DST="$DATA/plasma/plasmoids/$ID"
MARK="$DST/.seventasks-order-fix"
BACKUP="$DATA/seventasks-order-fix.backup"

say()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

restart_shell() {
  say "Restarting the Plasma shell"
  if have kquitapp6 && have kstart; then
    kquitapp6 plasmashell >/dev/null 2>&1; sleep 2; kstart plasmashell >/dev/null 2>&1 &
  else
    (plasmashell --replace >/dev/null 2>&1 &)
  fi
}

if [ "${1:-}" = "--undo" ]; then
  if [ -f "$MARK" ]; then
    rm -rf "$DST"
    [ -d "$BACKUP" ] && mv "$BACKUP" "$DST" && say "Put back your earlier custom SevenTasks copy"
    say "Removed the fix; the stock SevenTasks is used again."
    restart_shell
  else
    warn "The fix isn't installed."
  fi
  exit 0
fi

SRC=""
for d in /usr/share /usr/local/share $(echo "${XDG_DATA_DIRS:-}" | tr ':' ' '); do
  [ -f "$d/plasma/plasmoids/$ID/metadata.json" ] && { SRC="$d/plasma/plasmoids/$ID"; break; }
done
[ -n "$SRC" ] || { warn "Couldn't find the installed SevenTasks ($ID)."; exit 1; }

if [ -d "$DST" ] && [ ! -f "$MARK" ]; then
  warn "You already had a custom SevenTasks copy; backing it up to $BACKUP"
  rm -rf "$BACKUP"; mv "$DST" "$BACKUP"
fi

say "Copying SevenTasks into your home folder"
TMP="$DST.tmp.$$"
rm -rf "$TMP"; mkdir -p "$(dirname "$DST")"; cp -a "$SRC" "$TMP"

PYTHON=python3; have python3 || { warn "python3 is needed to apply the fix."; rm -rf "$TMP"; exit 1; }
if ! "$PYTHON" - "$TMP/contents/ui" <<'PY'
import sys, re, os
ui = sys.argv[1]
def patch(name, pattern, repl, flags=0):
    p = os.path.join(ui, name)
    s = open(p, encoding="utf-8").read()
    new, n = re.subn(pattern, repl, s, flags=flags)
    if n == 0:
        print(f"  pattern not found in {name}: {pattern[:60]}", file=sys.stderr)
        return False
    open(p, "w", encoding="utf-8").write(new)
    return True

ok = True
# 1. Use KDE's own rule so launch-in-place actually takes effect.
ok &= patch("main.qml",
    r"^(\s*)separateLaunchers:\s*false\s*$",
    r"""\1separateLaunchers: { // seventasks-order-fix: same rule as KDE's Task Manager
\1    if (!tasks.iconsOnly && !Plasmoid.configuration.separateLaunchers
\1        && Plasmoid.configuration.sortingStrategy === 1) {
\1        return false;
\1    }
\1    return true;
\1}""", re.M)
# 2. Save the order after Ctrl+Shift+arrow moves too (only drags were saved before).
ok &= patch("Task.qml",
    r"tasksModel\.move\(task\.index, task\.index - 1\);",
    "tasksModel.move(task.index, task.index - 1); tasksModel.syncLaunchers(); // seventasks-order-fix")
ok &= patch("Task.qml",
    r"tasksModel\.move\(task\.index, task\.index \+ 1\);",
    "tasksModel.move(task.index, task.index + 1); tasksModel.syncLaunchers(); // seventasks-order-fix")
sys.exit(0 if ok else 1)
PY
then
  warn "This SevenTasks version looks different from what the fix expects; nothing was changed."
  rm -rf "$TMP"
  [ -d "$BACKUP" ] && [ ! -d "$DST" ] && mv "$BACKUP" "$DST"
  exit 1
fi

rm -rf "$DST"; mv "$TMP" "$DST"; touch "$MARK"
say "Fix applied."
restart_shell
say "Drag your pinned items into the order you want once; it's saved from then on."
