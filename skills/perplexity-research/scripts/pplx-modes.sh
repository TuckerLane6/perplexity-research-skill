#!/usr/bin/env bash
# pplx-modes.sh: report what the app's composer is set to right now, and what
# models it is offering. It never submits a question and never changes a setting.
#
#   pplx-modes.sh            # modes only: reads the tree, touches nothing
#   pplx-modes.sh --models   # ALSO CLICKS: opens the model picker, reads it, and
#                            # closes it again by reselecting what was already
#                            # selected. Two clicks in an app the user may be
#                            # looking at. No mode or model is changed.
#
# Model lineups change every few weeks, so this reads the picker instead of
# carrying a list that would go stale. What it prints is what this account can
# actually pick today.
set -uo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/perplexity-research-skill/config"
PPLX=""
[ -f "$CONFIG" ] && PPLX="$(grep -E '^cli=' "$CONFIG" 2>/dev/null | cut -d= -f2- | tr -d '\r')"
if [ -z "$PPLX" ] || [ ! -x "$PPLX" ]; then
  if command -v pplx >/dev/null 2>&1; then PPLX="$(command -v pplx)"
  elif [ -x "$HOME/.local/bin/pplx" ]; then PPLX="$HOME/.local/bin/pplx"
  else echo "Desktop helper not found; see references/SETUP.md." >&2; exit 1; fi
fi

# The helper path comes from a hand-editable config file, and this script then
# runs it. Accept it only from the usual install locations so a stray edit to
# that file cannot turn into arbitrary execution.
#
# Resolve the path before judging it. A prefix match on the raw string is not a
# location check: "$HOME/.local/bin/../../../evil/pwned" starts with an allowed
# prefix and points somewhere else entirely, and a symlink dropped into an
# allowed directory does the same. Follow symlinks, resolve the directory
# physically, then compare whole directories. The allowed directories are
# resolved too, so an installation where one of them is itself a symlink still
# matches.
resolve_helper() {
  local p="$1" target dir hops=0
  while [ -L "$p" ] && [ "$hops" -lt 40 ]; do
    hops=$((hops + 1))
    target="$(readlink "$p")"
    case "$target" in
      /*) p="$target" ;;
      *)  p="$(dirname "$p")/$target" ;;
    esac
  done
  dir="$(cd -P "$(dirname "$p")" 2>/dev/null && pwd -P)" || return 1
  [ -n "$dir" ] || return 1
  printf '%s/%s\n' "$dir" "$(basename "$p")"
}

helper_allowed() {
  local resolved allowed real
  resolved="$(resolve_helper "$1")" || return 1
  resolved="$(dirname "$resolved")"
  for allowed in "$HOME/.local/bin" /usr/local/bin /opt/homebrew/bin; do
    real="$(cd -P "$allowed" 2>/dev/null && pwd -P)" || continue
    [ "$resolved" = "$real" ] && return 0
  done
  return 1
}

if ! helper_allowed "$PPLX"; then
  echo "Refusing to run a helper from an unexpected location: $PPLX" >&2
  echo "Expected it in ~/.local/bin, /usr/local/bin or /opt/homebrew/bin." >&2
  echo "A path that only starts with one of those, or a symlink pointing out of" >&2
  echo "them, is refused too: what counts is where the file actually is." >&2
  exit 1
fi

DUMP="$("$PPLX" dump 2>&1)"
if ! grep -qE '^\[windows\] count=[1-9]' <<<"$DUMP"; then
  open -g -a "Perplexity" >/dev/null 2>&1 || true
  sleep 3
  DUMP="$("$PPLX" dump 2>&1)"
fi

echo "== composer modes =="
# Only rows that actually report a state. Other controls share these labels (the
# sidebar has its own Search button), and a label with no state is not a mode.
printf '%s' "$DUMP" \
  | grep -E '\[AXButton\] desc=[^=]+ title=- val=(On|Off)$' \
  | sed -E 's/^ *\[AXButton\] desc=(.+) title=- val=(On|Off)$/  \1: \2/' \
  | sort -u

OTHER="$(printf '%s' "$DUMP" \
  | grep -E '\[AXButton\] desc=(Deep research|Control browser|Model council|Learn step by step) title=- val=-' \
  | sed -E 's/^ *\[AXButton\] desc=(.+) title=- val=-$/    \1/' \
  | sort -u)"
if [ -n "$OTHER" ]; then
  echo
  echo "  also offered here (the app does not expose whether they are selected):"
  printf '%s\n' "$OTHER"
fi

echo
if grep -qE '\[AXButton\] desc=(Computer|Control browser) title=- val=On' <<<"$DUMP"; then
  echo "  !! An agent mode is ON. It spends paid credits. Switch to Search before asking."
else
  echo "  Agent modes are off. Plain Search costs nothing beyond the existing plan."
fi

[ "${1:-}" = "--models" ] || exit 0

echo
echo "== models this account can pick =="
# The picker's entry point is labelled with the CURRENT selection, which differs
# per account and per app version, so try the usual labels rather than assuming.
OPENED=""
for label in "Best" "Model" "Choose a model" "Auto"; do
  if "$PPLX" click "$label" >/dev/null 2>&1; then OPENED="$label"; break; fi
done

if [ -z "$OPENED" ]; then
  echo "  The model picker was not reachable in this app state."
  echo "  Open a new session in the app and rerun, or leave model choice to the account default."
  exit 0
fi

sleep 2
"$PPLX" dump 2>&1 \
  | grep -E '\[AXStaticText\]' \
  | sed -E 's/^.*[[:space:]]val=//' \
  | awk 'length($0) >= 3 && length($0) <= 40 && !seen[$0]++' \
  | sed 's/^/  /'

# Close the picker by reselecting what was already selected: leaves the account
# exactly as it was found, which matters because a person shares this app. Say so
# when that fails, rather than reporting success over a picker left hanging open
# in someone's app.
if ! "$PPLX" click "$OPENED" >/dev/null 2>&1; then
  echo
  echo "  NOTE: the model picker was opened to read this list and could not be closed"
  echo "        again. It is still open on \"$OPENED\" in the app; press Escape there."
fi
echo
echo "  (rows marked with a higher tier belong to a plan this account may not have:"
echo "   never select one; it is an upgrade prompt, not a capability)"
