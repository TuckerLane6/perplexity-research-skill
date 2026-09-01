#!/usr/bin/env bash
# pplx-ask.sh "question" [max_wait_seconds]
#
# Runs one plain-Search round in the Perplexity desktop app and prints the answer.
# Background-safe: it sets the composer through the accessibility API, submits with
# an accessibility click, and reads the answer back out of the accessibility tree.
# No keystrokes, no clipboard writes, no window activation, so the person at the
# keyboard can keep working.
#
# Plain Search only. Never selects an agent mode and never touches a purchase
# control. Deep Research needs a mode click the user makes themselves first.
set -uo pipefail

Q="${1:?usage: pplx-ask.sh \"question\" [max_wait_seconds]}"
MAXWAIT="${2:-180}"

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/perplexity-research-skill/config"

PPLX=""
[ -f "$CONFIG" ] && PPLX="$(grep -E '^cli=' "$CONFIG" 2>/dev/null | cut -d= -f2-)"
if [ -z "$PPLX" ] || [ ! -x "$PPLX" ]; then
  if command -v pplx >/dev/null 2>&1; then PPLX="$(command -v pplx)"
  elif [ -x "$HOME/.local/bin/pplx" ]; then PPLX="$HOME/.local/bin/pplx"
  else
    echo "The desktop helper was not found. Run scripts/pplx-setup.sh --install-cli," >&2
    echo "or switch to the browser path with scripts/pplx-setup.sh --path browser." >&2
    exit 1
  fi
fi

has_window() { "$PPLX" dump 2>&1 | grep -qE '^\[windows\] count=[1-9]'; }
has_composer() { "$PPLX" dump 2>&1 | grep -qE '\[AXTextArea\]'; }

# The app can be running with no window at all (its window was closed, or a stray
# click dismissed it). Reopen it WITHOUT activating it: -g leaves the person's
# frontmost app exactly where it was.
ensure_window() {
  has_window && return 0
  open -g -a "Perplexity" >/dev/null 2>&1 || true
  for _ in 1 2 3 4 5; do sleep 2; has_window && return 0; done
  echo "The Perplexity app has no window and would not reopen. Open it once, then retry." >&2
  return 1
}

ensure_window || exit 1

# Prefer a fresh thread so the question is not read as a follow-up to whatever was
# asked before. This click is best-effort on purpose: the same label also exists as
# a menu item on some builds, and hitting that one opens a menu and can dismiss the
# window — so verify the composer afterwards and recover rather than trusting it.
"$PPLX" click "New Session" >/dev/null 2>&1 || true
sleep 2
if ! has_composer; then
  ensure_window || exit 1
  sleep 1
  has_composer || { echo "The composer is not reachable. Open the Perplexity app once, then retry." >&2; exit 1; }
fi

printf '%s' "$Q" | "$PPLX" set-input || { echo "Could not write the question into the composer." >&2; exit 1; }
sleep 1

# The composer's send control is an arrow button; its description varies by build.
"$PPLX" click "arrow-right" >/dev/null 2>&1 \
  || "$PPLX" click "arrow-up" >/dev/null 2>&1 \
  || { echo "Could not submit the question." >&2; exit 1; }

# The Copy button appears exactly when the answer has finished streaming.
ELAPSED=0
DONE=0
while [ "$ELAPSED" -lt "$MAXWAIT" ]; do
  sleep 8; ELAPSED=$((ELAPSED + 8))
  if "$PPLX" dump 2>&1 | grep -qE '\[AXButton\] desc=Copy title='; then DONE=1; break; fi
done

if [ "$DONE" != 1 ]; then
  echo "NOT-FINISHED within ${MAXWAIT}s. The thread is still in the app; re-read it later with:" >&2
  echo "  $PPLX dump 2>&1 | grep AXStaticText" >&2
  exit 2
fi

# Clipboard-free readback: answer text lands in the tree as static-text lines.
#
# The sidebar lists the person's other recent threads, and those lines are in the
# tree too — printing them would spill unrelated history into the transcript. The
# question itself appears twice: once in that sidebar list, then again at the top
# of the open thread. Everything after its LAST occurrence is this answer, so cut
# there. The short leftovers after the cut are step labels, dropped by a length
# floor.
"$PPLX" dump 2>&1 \
  | grep -E '^\s*\[AXStaticText\]' \
  | sed -E 's/^.*[[:space:]]val=//' \
  | awk -v q="${Q:0:40}" '
      { line[NR] = $0; if (index($0, q) > 0) last = NR }
      END {
        if (!last) print "(could not locate the question in the thread; showing all long text found)" > "/dev/stderr"
        for (i = (last ? last + 1 : 1); i <= NR; i++)
          if (length(line[i]) >= 40 && !seen[line[i]]++) print line[i]
      }'

echo
echo "--- answered on the user's own Perplexity account, plain Search, no credits spent ---"
