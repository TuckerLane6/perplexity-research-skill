#!/usr/bin/env bash
# pplx-ask.sh "question" [max_wait_seconds] [--credits-approved]
#
# Runs one plain-Search round in the Perplexity desktop app and prints the answer.
# Background-safe: it sets the composer through the accessibility API, submits with
# an accessibility click, and reads the answer back out of the accessibility tree.
# No keystrokes and no window activation, so the person at the keyboard can keep
# working. It does not use the clipboard, except for one case: when a long answer
# is truncated in the tree it borrows the clipboard for about a second and puts
# the previous contents straight back.
#
# Plain Search by default, which costs nothing beyond the plan. If the composer is
# in a mode that spends credits, this stops rather than submitting - unless the
# caller passes --credits-approved, which it may only do after the user has said
# yes to THAT run in the conversation. It never touches a purchase control either
# way: spending held credits is the user's call, buying more is not this script's.
set -uo pipefail

# This script drives the macOS desktop app through the macOS accessibility API.
# On any other platform the browser path is the one that works, so say that
# plainly instead of failing further down with a confusing error.
if [ "$(uname -s 2>/dev/null)" != "Darwin" ]; then
  echo "This script only runs on macOS: it drives the Perplexity desktop app through" >&2
  echo "the macOS accessibility API. On this platform use the browser path -" >&2
  echo "  scripts/pplx-setup.sh --path browser   (or pplx-setup.ps1 -Path browser)" >&2
  echo "- and drive perplexity.ai with the browser automation this session has." >&2
  exit 1
fi

CREDITS_APPROVED=0
ARGS=()
for a in "$@"; do
  case "$a" in
    --credits-approved) CREDITS_APPROVED=1 ;;
    *) ARGS+=("$a") ;;
  esac
done
set -- "${ARGS[@]+"${ARGS[@]}"}"

case "${1:-}" in
  -h|--help|"")
    echo "usage: pplx-ask.sh \"question\" [max_wait_seconds] [--credits-approved]"
    echo
    echo "Asks the Perplexity desktop app one plain-Search question and prints the answer."
    echo "macOS only. On Windows and Linux use the browser path; see references/SETUP.md."
    exit 0 ;;
esac

Q="$1"
MAXWAIT="${2:-180}"
case "$MAXWAIT" in
  ''|*[!0-9]*) echo "max_wait_seconds must be a whole number of seconds." >&2; exit 1 ;;
esac

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/perplexity-research-skill/config"

PPLX=""
[ -f "$CONFIG" ] && PPLX="$(grep -E '^cli=' "$CONFIG" 2>/dev/null | cut -d= -f2- | tr -d '\r')"
if [ -z "$PPLX" ] || [ ! -x "$PPLX" ]; then
  if command -v pplx >/dev/null 2>&1; then PPLX="$(command -v pplx)"
  elif [ -x "$HOME/.local/bin/pplx" ]; then PPLX="$HOME/.local/bin/pplx"
  else
    echo "The desktop helper was not found. Run scripts/pplx-setup.sh --install-cli," >&2
    echo "or switch to the browser path with scripts/pplx-setup.sh --path browser." >&2
    exit 1
  fi
fi

# The helper path comes from a hand-editable config file, and this script then
# runs it. Accept it only from the usual install locations so a stray edit to
# that file cannot turn into arbitrary execution.
case "$PPLX" in
  "$HOME/.local/bin/"*|/usr/local/bin/*|/opt/homebrew/bin/*) ;;
  *) echo "Refusing to run a helper from an unexpected location: $PPLX" >&2
     echo "Expected it under ~/.local/bin, /usr/local/bin or /opt/homebrew/bin." >&2
     exit 1 ;;
esac

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
# window, so verify the composer afterwards and recover rather than trusting it.
"$PPLX" click "New Session" >/dev/null 2>&1 || true
sleep 2
if ! has_composer; then
  ensure_window || exit 1
  sleep 1
  has_composer || { echo "The composer is not reachable. Open the Perplexity app once, then retry." >&2; exit 1; }
fi

# Credit guard, checked mechanically rather than remembered. The composer's mode
# buttons report their own state in the accessibility tree (val=On / val=Off), so
# an agent mode that would spend paid credits can be caught BEFORE submitting
# instead of discovered afterwards on the bill.
MODES="$("$PPLX" dump 2>&1)"
if printf '%s' "$MODES" | grep -qE '\[AXButton\] desc=(Computer|Control browser) title=- val=On'; then
  if [ "$CREDITS_APPROVED" = 1 ]; then
    echo "NOTE: submitting in a credit-spending mode, with the caller asserting the user approved this run." >&2
  else
    echo "STOPPED: the composer is in a mode that spends the user's credits." >&2
    echo "This is allowed, but it needs a yes first. Tell the user which mode it is," >&2
    echo "that it spends credits rather than quota, and what the run looks like." >&2
    echo "If they say yes, re-run this exact command with --credits-approved." >&2
    echo "If they would rather not, switch the composer back to Search." >&2
    exit 3
  fi
fi
# Not finding a paid mode is not the same as confirming a free one. If the app
# renames its buttons, both checks miss, and continuing would submit blind into
# whatever mode is actually selected. Fail closed: require positive confirmation
# of Search, or an explicit approval, before spending anything.
SEARCH_CONFIRMED=0
printf '%s' "$MODES" | grep -qE '\[AXButton\] desc=Search title=- val=On' && SEARCH_CONFIRMED=1
if [ "$SEARCH_CONFIRMED" != 1 ] && [ "$CREDITS_APPROVED" != 1 ]; then
  echo "STOPPED: could not confirm the composer is in Search mode." >&2
  echo "This build may name its mode buttons differently, so the run could be" >&2
  echo "submitting into a mode that spends credits. Check the composer in the app." >&2
  echo "If it is on Search, or the user accepts the cost, re-run with --credits-approved." >&2
  exit 3
fi

printf '%s' "$Q" | "$PPLX" set-input || { echo "Could not write the question into the composer." >&2; exit 1; }
sleep 1

# Writing the value can report success while the composer ends up empty (the app
# re-renders the composer on some transitions). Confirm the text is really there
# before submitting, and write it once more if it is not, submitting an empty
# composer produces a confusing "nothing happened".
if ! "$PPLX" dump 2>&1 | grep -qE '\[AXTextArea\][^=]*val=.+'; then
  sleep 1
  printf '%s' "$Q" | "$PPLX" set-input >/dev/null 2>&1 || true
  sleep 1
fi

# The send control is an arrow button whose accessibility description differs by
# build, and on some builds it is unlabelled until the composer holds text. Try
# the known labels in turn rather than assuming one.
SUBMITTED=0
for label in "arrow-right" "arrow-up" "Submit" "Send" "send"; do
  if "$PPLX" click "$label" >/dev/null 2>&1; then SUBMITTED=1; break; fi
done
if [ "$SUBMITTED" != 1 ]; then
  echo "Could not submit: no send control was found in the composer." >&2
  echo "The question is sitting in the composer; press Return in the app to send it," >&2
  echo "or see references/SETUP.md (the send arrow's description varies by build)." >&2
  exit 1
fi

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
# tree too, printing them would spill unrelated history into the transcript. The
# question itself appears twice: once in that sidebar list, then again at the top
# of the open thread. Everything after its LAST occurrence is this answer, so cut
# there. The short leftovers after the cut are step labels, dropped by a length
# floor.
#
# Do NOT filter by line length: answers contain short lines (list items, "Yes.",
# a name, a number) and a length floor silently truncates them. Filter by what the
# line IS instead, the app's own chrome labels are a small known set.
read_tree() {
"$PPLX" dump 2>&1 \
  | grep -E '^\s*\[AXStaticText\]' \
  | sed -E 's/^.*[[:space:]]val=//' \
  | PPLX_Q="$Q" awk '
      BEGIN {
        q = substr(ENVIRON["PPLX_Q"], 1, 40)
        # UI chrome that sits inside the answer region on some builds
        # Chrome labels only. "Pro", "Search" and bare numbers were in this list
        # and were eating real answers: a one-word reply, a year, a count.
        noise = "^(MCP Tool|Success|Copy|Share|Answer|Sources|Images|Show more|Related|Ask a follow-up|[[:space:]]*)$"
      }
      { line[NR] = $0; if (index($0, q) > 0) last = NR }
      END {
        if (!last) {
          # Without the question as a boundary there is no way to tell this
          # answer from the rest of the tree, which includes the sidebar list of
          # the account other threads. Refuse rather than print someone else\047s
          # research.
          print "ANSWER-NOT-LOCATED: the question was not found in the thread, so the answer" > "/dev/stderr"
          print "region could not be isolated. Nothing printed, to avoid returning unrelated threads." > "/dev/stderr"
          exit 9
        }
        for (i = last + 1; i <= NR; i++) {
          t = line[i]
          if (t ~ noise) continue
          if (seen[t]++) continue
          print t
        }
      }'
}

# The app renders the answer lazily, so the accessibility tree can hold only the
# first part of a long one. A finished answer ends on sentence punctuation; if it
# does not, the tree gave us a fragment and the clipboard is the reliable source.
# The clipboard belongs to the person at the keyboard, so it is saved first and put
# straight back, it is borrowed for about a second, never kept.
read_clipboard() {
  local saved answer flavours
  # pbpaste and pbcopy only carry plain text. If the clipboard currently holds an
  # image, RTF or files, a save-and-restore round trip would silently replace it
  # with empty text. Losing someone's clipboard is worse than a short answer, so
  # skip the fallback entirely unless the clipboard is text or empty.
  flavours="$(osascript -e 'clipboard info' 2>/dev/null || true)"
  case "$flavours" in
    ""|*utf8*|*"«class utf8»"*|*string*) ;;
    *) echo "NOTE: clipboard holds non-text content, so it was left alone and the" >&2
       echo "      long-answer fallback was skipped." >&2
       return 1 ;;
  esac
  saved="$(pbpaste 2>/dev/null || true)"
  "$PPLX" click "Copy" >/dev/null 2>&1 || return 1
  sleep 1
  answer="$(pbpaste 2>/dev/null || true)"
  printf '%s' "$saved" | pbcopy 2>/dev/null || true
  [ -n "$answer" ] || return 1
  printf '%s\n' "$answer"
}

# A copied blob is only trustworthy if it is THIS answer. There can be more than
# one Copy control in the tree, and clicking the wrong one returns a completely
# different thread's text, which is far worse than a short answer, because it
# looks like a real reply to the question that was just asked. So the copy is
# accepted only when it visibly overlaps the fragment the tree already gave us,
# and that fragment is known to belong to this thread because it sits after this
# question.
copy_matches_this_answer() {
  local copied="$1" fragment="$2" line
  while IFS= read -r line; do
    line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ "${#line}" -ge 12 ] || continue
    case "$copied" in *"$line"*) return 0 ;; esac
  done <<EOF
$fragment
EOF
  return 1
}

# The Copy button appearing means the answer finished streaming, but the
# accessibility tree fills in behind it, read once at that instant and you get a
# fragment. Poll until two consecutive reads agree, the same way the browser path
# waits for the page to stop growing.
ANSWER="$(read_tree)"
for _ in 1 2 3 4 5; do
  sleep 2
  NEXT="$(read_tree)"
  [ "$NEXT" = "$ANSWER" ] && break
  ANSWER="$NEXT"
done
SOURCE_OF_TEXT="accessibility tree, clipboard untouched"
# The app appends an object-replacement glyph where an inline citation marker
# sits, so strip that (and trailing space) before judging whether the text ends
# on sentence punctuation, otherwise a complete answer reads as truncated.
LAST_LINE="$(printf '%s' "$ANSWER" | tail -1 | sed -e 's/\xef\xbf\xbc//g' -e 's/[[:space:]]*$//')"
case "$LAST_LINE" in
  *[.!?\"\)]|*：|*。) : ;;                     # ends on sentence punctuation: complete
  *)
    if FULL="$(read_clipboard)" && copy_matches_this_answer "$FULL" "$ANSWER"; then
      ANSWER="$FULL"
      SOURCE_OF_TEXT="clipboard (the tree held only a fragment); previous clipboard restored"
    else
      SOURCE_OF_TEXT="accessibility tree, TRUNCATED, and the copied text did not match this thread, so it was discarded"
      ANSWER="$ANSWER
[TRUNCATED: the app exposed only the start of this answer. Open the thread in the
app to read the rest, or ask a narrower question that fits a short reply.]"
    fi ;;
esac
printf '%s\n' "$ANSWER"

echo
# The whole point of asking Perplexity rather than answering from memory is the
# sourcing, so say plainly whether this answer has any.
if "$PPLX" dump 2>&1 | grep -qE '\[AXButton\] desc=Sources title='; then
  echo "--- sources: the thread has a Sources panel; open it in the app to read the list ---"
else
  echo "--- NO SOURCES PANEL: treat this as unsourced. Do not quote it onward as fact. ---"
fi
echo "--- read via: $SOURCE_OF_TEXT ---"
if [ "$SEARCH_CONFIRMED" = 1 ] && [ "$CREDITS_APPROVED" != 1 ]; then
  echo "--- ran as plain Search on the user's own account: no credits spent ---"
elif [ "$CREDITS_APPROVED" = 1 ]; then
  echo "--- ran with --credits-approved: this may have spent credits. Tell the user. ---"
else
  echo "--- mode could not be confirmed: do not claim this was free. Check the app. ---"
fi
