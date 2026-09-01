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

# NOTE: never pipe a dump straight into `grep -q`. With `pipefail` set, grep -q
# exits on the first match, the writer takes SIGPIPE, and the pipeline reports
# 141, so a MATCH reads as NO MATCH once the tree outgrows the pipe buffer. Every
# check below captures the dump first and matches with a here-string.
dump_now() { "$PPLX" dump 2>&1; }
has_window() { grep -qE '^\[windows\] count=[1-9]' <<<"$(dump_now)"; }
has_composer() { grep -qE '\[AXTextArea\]' <<<"$(dump_now)"; }

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
  # Do not rely on ensure_window to recover here. A running app whose window has
  # been closed still reports `[windows] count=1`, with the application element
  # standing in for the window, so has_window is satisfied and the reopen inside
  # ensure_window never fires while the composer is genuinely gone. Ask for the
  # window back directly instead, then re-check.
  open -g -a "Perplexity" >/dev/null 2>&1 || true
  for _ in 1 2 3 4 5; do sleep 2; has_composer && break; done
  if ! has_composer; then
    echo "The composer is not reachable. The app is running, but it has no usable" >&2
    echo "window and a background reopen did not bring one back. Open a window in the" >&2
    echo "app yourself, by clicking it in the Dock or pressing Command-N in it, then" >&2
    echo "retry. This can happen after a click lands on the New Session MENU ITEM" >&2
    echo "rather than the button, which dismisses the window." >&2
    exit 1
  fi
fi

# Credit guard, checked mechanically rather than remembered. The composer's mode
# buttons report their own state in the accessibility tree (val=On / val=Off), so
# an agent mode that would spend paid credits can be caught BEFORE submitting
# instead of discovered afterwards on the bill.
MODES="$("$PPLX" dump 2>&1)"
if grep -qE '\[AXButton\] desc=(Computer|Control browser) title=- val=On' <<<"$MODES"; then
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
grep -qE '\[AXButton\] desc=Search title=- val=On' <<<"$MODES" && SEARCH_CONFIRMED=1
if [ "$SEARCH_CONFIRMED" != 1 ] && [ "$CREDITS_APPROVED" != 1 ]; then
  echo "STOPPED: could not confirm the composer is in Search mode." >&2
  echo "This build may name its mode buttons differently, so the run could be" >&2
  echo "submitting into a mode that spends credits. Check the composer in the app." >&2
  echo "If it is on Search, or the user accepts the cost, re-run with --credits-approved." >&2
  exit 3
fi

# >/dev/null: the helper reports "set N chars" on stdout, and this script's stdout
# is the answer. Left alone it prints that line above the answer, where a caller
# quoting the output would carry it along as though it were part of the reply.
printf '%s' "$Q" | "$PPLX" set-input >/dev/null || { echo "Could not write the question into the composer." >&2; exit 1; }
sleep 1

# Writing the value can report success while the composer ends up empty (the app
# re-renders the composer on some transitions). Confirm the text is really there
# before submitting, and write it once more if it is not, submitting an empty
# composer produces a confusing "nothing happened".
#
# Match to the END of the row, not with [^=]*: a real row reads
#   [AXTextArea] desc=- title=- val=the question
# and [^=]* cannot cross the = in desc=, so that shape never matched and this
# guard silently re-wrote the composer on every single run. An empty composer
# reports a bare `val=` with nothing after it, which is what .+ separates.
if ! grep -qE '\[AXTextArea\].*[[:space:]]val=.+' <<<"$(dump_now)"; then
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
  if grep -qE '\[AXButton\] desc=Copy title=' <<<"$(dump_now)"; then DONE=1; break; fi
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
# there. The leftovers after the cut are the app's own step labels, dropped by the
# noise list below.
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
        # and were eating real answers: a one-word reply, a year, a count. Add a
        # label here only after seeing the app actually print it, for the same
        # reason: a plausible-looking guess silently deletes a real answer.
        noise = "^(MCP Tool|Success|Copy|Share|Answer|Sources|Images|Show more|Related|Ask a follow-up|Searching the web|[[:space:]]*)$"
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
          exit 4
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
#
# The RETURN CODE says which of these happened, because the caller has to tell the
# user the truth about their clipboard and cannot see inside this function: it runs
# inside $( ), so anything assigned to a variable here is discarded.
#   0  the answer is on stdout, and the previous clipboard was put back
#   7  the answer is on stdout, but the previous clipboard could NOT be put back
#   2  skipped: the clipboard's contents could not be read
#   3  skipped: the clipboard holds something other than plain text
#   4  skipped: the clipboard could not be saved, so it was not touched
#   5  skipped: the Copy control would not click, so nothing was copied
#   6  skipped: the copy came back empty
# Everything except 0 and 7 means NOTHING WAS COPIED. Reporting those as "the
# copied text did not match" told people their app was serving other threads when
# in fact their clipboard held a picture.
read_clipboard() {
  local saved answer flavours field restore_failed=0
  # pbpaste and pbcopy only carry plain text. If the clipboard currently holds an
  # image, styled text or files, a save-and-restore round trip would silently
  # replace it with plain text or nothing. Losing someone's clipboard is worse
  # than a short answer, so skip the fallback entirely unless every flavour on the
  # clipboard is a plain-text one. A failed lookup is also a skip: not knowing is
  # not permission.
  #
  # This is an ALLOWLIST on purpose. It started as a list of rich flavours to
  # refuse, which let through everything nobody thought to name: spreadsheet and
  # presentation clippings arrive under an app-specific dynamic type
  # («class dyn.ah62d4rv...»), and GIFf, PICT and icns were all missing too.
  #
  # `clipboard info` returns flavour and BYTE SIZE alternating, comma separated:
  #   «class utf8», 99, «class ut16», 200, string, 99, Unicode text, 198
  # so the numeric fields have to be dropped before the allowlist runs, or every
  # clipboard on earth fails it.
  flavours="$(osascript -e 'clipboard info' 2>/dev/null)" || {
    echo "NOTE: could not read the clipboard's contents, so it was left alone." >&2
    return 2; }
  [ -n "$flavours" ] || return 2
  while IFS= read -r field; do
    field="$(printf '%s' "$field" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    case "$field" in
      ''|*[!0-9]*) ;;                                    # not a size: check it below
      *) continue ;;                                     # a byte count: skip
    esac
    case "$field" in
      ''|string|"Unicode text"|"«class utf8»"|"«class ut16»"|"«class TEXT»") ;;
      *) echo "NOTE: the clipboard holds something other than plain text ($field)," >&2
         echo "      so it was left alone and the long-answer fallback was skipped." >&2
         return 3 ;;
    esac
  done <<EOF
$(printf '%s' "$flavours" | tr ',' '\n')
EOF
  # From here the clipboard is about to be borrowed, so a failure to save it or to
  # put it back is the exact loss this function exists to prevent. Say so out loud
  # rather than swallowing it: silently handing someone's clipboard to a different
  # thread's text is the worst outcome available here.
  #
  # Check that the clipboard can be read BEFORE capturing it, because the capture
  # below cannot report a failure: it ends in printf, so the exit status is
  # printf's. The trailing X is a sentinel. Command substitution strips trailing
  # newlines, so "$(pbpaste)" alone silently shortens any clipboard ending in a
  # blank line, and putting that back is not putting it back.
  pbpaste >/dev/null 2>&1 || {
    echo "NOTE: the clipboard could not be saved, so it was left alone." >&2
    return 4; }
  saved="$(pbpaste 2>/dev/null; printf 'X')"
  saved="${saved%X}"
  "$PPLX" click "Copy" >/dev/null 2>&1 || return 5
  sleep 1
  answer="$(pbpaste 2>/dev/null || true)"
  printf '%s' "$saved" | pbcopy 2>/dev/null || {
    restore_failed=1
    echo "WARNING: the clipboard could not be put back. It now holds the copied" >&2
    echo "         answer, not what was there before. Copy something to clear it." >&2; }
  [ -n "$answer" ] || return 6
  printf '%s\n' "$answer"
  [ "$restore_failed" = 1 ] && return 7
  return 0
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
#
# A refusal from read_tree (the question was not found, so the answer region
# could not be isolated) must end the run. Assigning without checking the status
# left ANSWER empty, and an empty answer reads as "unfinished", which then sent
# the run on to the clipboard fallback and printed truncation boilerplate as
# though it were a real reply. Exit 4 instead, the code AGENTS.md documents.
if ! ANSWER="$(read_tree)"; then exit 4; fi
for _ in 1 2 3 4 5; do
  sleep 2
  NEXT="$(read_tree)" || break
  [ "$NEXT" = "$ANSWER" ] && break
  ANSWER="$NEXT"
done
SOURCE_OF_TEXT="accessibility tree, clipboard untouched"

# The question was found but nothing followed it: the answer region is empty. This
# is a real state, not a contrived one, because the wait loop above breaks as soon
# as ANY Copy control exists, and a leftover Copy control from the previous thread
# satisfies it before the new answer renders.
#
# There is no answer here to be truncated. Calling it truncated and exiting 0 hands
# the caller boilerplate where the reply should be and tells it everything went
# fine. Exit 2, the code that already means "not finished, the thread is still in
# the app, check back".
case "$(printf '%s' "$ANSWER" | tr -d '[:space:]')" in
  "")
    echo "NOT-FINISHED: the thread was located but its answer region is still empty," >&2
    echo "so the app had not rendered any of the answer yet. Nothing printed. The" >&2
    echo "thread is in the app; retry, or re-read it there." >&2
    exit 2 ;;
esac

# The app appends an object-replacement glyph where an inline citation marker
# sits, so strip that (and trailing space) before judging whether the text ends
# on sentence punctuation, otherwise a complete answer reads as truncated.
LAST_LINE="$(printf '%s' "$ANSWER" | tail -1 | sed -e 's/\xef\xbf\xbc//g' -e 's/[[:space:]]*$//')"
case "$LAST_LINE" in
  *[.!?\"\)\]:]|*：|*。) : ;;                     # ends on sentence punctuation: complete
  *)
    # Report what actually happened. Four different outcomes used to print the same
    # sentence about a copy that did not match, including the cases where nothing
    # was ever copied at all.
    FULL="$(read_clipboard)"; CLIP_RC=$?
    case "$CLIP_RC" in
      0|7)
        RESTORE_NOTE="previous clipboard restored"
        [ "$CLIP_RC" = 7 ] && RESTORE_NOTE="WARNING: the previous clipboard could NOT be put back and now holds this answer"
        if copy_matches_this_answer "$FULL" "$ANSWER"; then
          ANSWER="$FULL"
          SOURCE_OF_TEXT="clipboard (the tree held only a fragment); $RESTORE_NOTE"
        else
          SOURCE_OF_TEXT="accessibility tree, TRUNCATED. A copy was taken but its text did not belong to this thread, so it was discarded; $RESTORE_NOTE"
          ANSWER="$ANSWER
[TRUNCATED: the app exposed only the start of this answer. Open the thread in the
app to read the rest, or ask a narrower question that fits a short reply.]"
        fi ;;
      *)
        case "$CLIP_RC" in
          2) WHY="the clipboard's contents could not be read" ;;
          3) WHY="the clipboard holds something other than plain text" ;;
          4) WHY="the clipboard could not be saved" ;;
          5) WHY="the Copy control would not click" ;;
          6) WHY="the copy came back empty" ;;
          *) WHY="the fallback did not run" ;;
        esac
        SOURCE_OF_TEXT="accessibility tree, TRUNCATED. Nothing was copied and the clipboard was not touched, because $WHY"
        ANSWER="$ANSWER
[TRUNCATED: the app exposed only the start of this answer. Open the thread in the
app to read the rest, or ask a narrower question that fits a short reply.]" ;;
    esac ;;
esac
printf '%s\n' "$ANSWER"

echo
# The whole point of asking Perplexity rather than answering from memory is the
# sourcing, so say plainly whether this answer has any.
if grep -qE '\[AXButton\] desc=Sources title=' <<<"$(dump_now)"; then
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
