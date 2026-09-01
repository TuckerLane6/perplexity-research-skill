#!/usr/bin/env bash
# pplx-setup.sh: choose and record how this machine talks to Perplexity.
#
#   pplx-setup.sh                 # report what is available here, change nothing
#   pplx-setup.sh --path app      # record the desktop-app path
#   pplx-setup.sh --path browser  # record the browser path
#   pplx-setup.sh --install-cli   # build the desktop helper from source (needs Go + git)
#   pplx-setup.sh --doctor        # prove the recorded path actually works right now
#
# Writes: ${XDG_CONFIG_HOME:-$HOME/.config}/perplexity-research-skill/config
#         and, only with --install-cli, $HOME/.local/bin/pplx plus a build
#         directory under $TMPDIR
# Everything is per-machine. Nothing here is specific to any one user or repo.
set -uo pipefail

# Platform detection. The desktop-app path drives the macOS app through the macOS
# accessibility API, so it exists on macOS only; everywhere else the browser path
# is the one that works. Git Bash, MSYS and Cygwin all report their own uname, and
# WSL reports Linux, so name them explicitly rather than assuming "not Darwin =
# Linux".
platform() {
  case "$(uname -s 2>/dev/null)" in
    Darwin) echo macos ;;
    MINGW*|MSYS*|CYGWIN*) echo windows ;;
    Linux)
      if grep -qiE "(microsoft|wsl)" /proc/version 2>/dev/null; then echo wsl; else echo linux; fi ;;
    *) [ -n "${OS:-}" ] && [ "${OS:-}" = "Windows_NT" ] && echo windows || echo unknown ;;
  esac
}
PLATFORM="$(platform)"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/perplexity-research-skill"
CONFIG="$CONFIG_DIR/config"
CLI_UPSTREAM="https://github.com/toby1991/pplx-cli"
# Pinned so an upstream change cannot compile onto your machine unreviewed. This
# helper is granted macOS Accessibility permission, so it can read any window;
# that is worth pinning for. Bump it deliberately after reading the diff.
CLI_COMMIT="4acbf43ac192b527207e1c89eaada6ccc360a2b9"

# Only these locations count. The ask and modes scripts refuse a helper from
# anywhere else, so setup must not find, run, or record one either: a config
# pointing outside the list would pass here and be rejected there.
cli_allowed() {
  case "$1" in
    "$HOME/.local/bin/"*|/usr/local/bin/*|/opt/homebrew/bin/*) return 0 ;;
    *) return 1 ;;
  esac
}

find_cli() {
  local onpath
  if onpath="$(command -v pplx 2>/dev/null)" && cli_allowed "$onpath"; then
    echo "$onpath"; return 0
  fi
  for c in "$HOME/.local/bin/pplx" "/usr/local/bin/pplx" "/opt/homebrew/bin/pplx"; do
    [ -x "$c" ] && { echo "$c"; return 0; }
  done
  return 1
}

find_app() {
  for a in "/Applications/Perplexity.app" "$HOME/Applications/Perplexity.app"; do
    [ -d "$a" ] && { echo "$a"; return 0; }
  done
  return 1
}

report() {
  case "$PLATFORM" in
    macos)   echo "Platform:        macOS, both paths available" ;;
    windows) echo "Platform:        Windows, browser path (the app path is macOS only)" ;;
    wsl)     echo "Platform:        WSL, browser path, driving a browser on the Windows side" ;;
    linux)   echo "Platform:        Linux, browser path (the app path is macOS only)" ;;
    *)       echo "Platform:        unrecognised, browser path is the safe choice" ;;
  esac
  if APP=$(find_app); then echo "Perplexity app:  found at $APP"
  else echo "Perplexity app:  not found"; fi
  if CLI=$(find_cli); then echo "Desktop helper:  found at $CLI"
  elif [ "$PLATFORM" = "macos" ]; then echo "Desktop helper:  not installed (build it with --install-cli)"
  else echo "Desktop helper:  not applicable on this platform"; fi
  if [ -f "$CONFIG" ]; then echo "Recorded path:   $(grep -E '^path=' "$CONFIG" | cut -d= -f2 | tr -d '\r')"
  else echo "Recorded path:   none yet, ask the user which they prefer, then rerun with --path"; fi

  # The app path is the recommended default wherever it can run: it works in the
  # background instead of taking over a browser window the person is using.
  if [ "$PLATFORM" = "macos" ] && find_app >/dev/null; then
    echo "Recommended:     app  (this machine can run it; offer it first)"
  elif [ "$PLATFORM" = "macos" ]; then
    echo "Recommended:     app, once the Perplexity desktop app is installed; browser until then"
  else
    echo "Recommended:     browser  (the only path on this platform, do not ask, just say so)"
  fi
}

write_config() {
  local choice="$1"
  mkdir -p "$CONFIG_DIR"
  {
    echo "# written by pplx-setup.sh, safe to edit or delete"
    echo "path=$choice"
    if [ "$choice" = "app" ] && CLI=$(find_cli); then echo "cli=$CLI"; fi
  } > "$CONFIG"
  echo "Recorded: path=$choice  ->  $CONFIG"
}

install_cli() {
  command -v go  >/dev/null 2>&1 || { echo "Go is required to build the helper. Install Go, then rerun."; exit 1; }
  command -v git >/dev/null 2>&1 || { echo "git is required to build the helper. Install git, then rerun."; exit 1; }
  [ "$PLATFORM" = "macos" ] || { echo "The desktop helper drives the macOS app and only builds on macOS. Use the browser path instead."; exit 1; }

  # Build in a throwaway directory. The name is fixed and the path is checked
  # before the delete, so a strange TMPDIR cannot turn this into a wider wipe.
  SRC="${TMPDIR:-/tmp}/pplx-cli-src"
  case "$SRC" in
    */pplx-cli-src) ;;
    *) echo "Refusing to build: unexpected temp path '$SRC'."; exit 1 ;;
  esac
  [ -e "$SRC" ] && rm -rf "$SRC"

  echo "Cloning $CLI_UPSTREAM into $SRC and building it with Go."
  echo "That is third-party open-source code, pinned to commit ${CLI_COMMIT:0:12}."
  echo "Read it there if you would rather not build it."
  git clone --quiet "$CLI_UPSTREAM" "$SRC" || { echo "clone failed"; exit 1; }
  ( cd "$SRC" && git checkout --quiet "$CLI_COMMIT" ) || {
    echo "Could not check out the pinned commit $CLI_COMMIT."
    echo "Upstream may have rewritten history. Review the repo before changing the pin."
    exit 1; }
  mkdir -p "$HOME/.local/bin"
  ( cd "$SRC" && GOFLAGS=-mod=readonly go build -o "$HOME/.local/bin/pplx" . ) || {
    echo "Build failed. The upstream helper may need its bundle id and URL scheme updated"
    echo "for your app version, see references/SETUP.md."
    exit 1; }
  echo "Built: $HOME/.local/bin/pplx"
  echo "macOS will ask for Accessibility permission the first time it drives the app."
  echo "Grant it under System Settings > Privacy & Security > Accessibility."
}

# --doctor proves the chosen path is actually live right now, instead of trusting
# that an install done once still works. It reads state only: no question is asked
# and nothing is submitted.
doctor() {
  local ok=0
  echo "== doctor =="
  report
  echo
  local chosen="none"
  [ -f "$CONFIG" ] && chosen="$(grep -E '^path=' "$CONFIG" | cut -d= -f2 | tr -d '\r')"

  case "$chosen" in
    app)
      if ! CLI=$(find_cli); then echo "FAIL  helper missing, run --install-cli"; return 1; fi
      if "$CLI" dump 2>&1 | grep -qE '^\[windows\] count=[1-9]'; then
        echo "PASS  the app is running with a window"
      else
        echo "WARN  the app has no window; the ask script will reopen it in the background"
      fi
      if "$CLI" dump 2>&1 | grep -qiE '\[AXButton\] desc=(Sign in|Log in|Sign up|Continue with)'; then
        echo "FAIL  the app looks signed out, the user signs in themselves, by hand,"
        echo "      then rerun. This skill never signs in on anyone's behalf."; ok=1
      else
        echo "PASS  no sign-in screen detected"
      fi
      if "$CLI" dump 2>&1 | grep -qE '\[AXTextArea\]'; then
        echo "PASS  the composer is reachable"
      else
        echo "FAIL  the composer is not reachable, open the app once, then rerun"; ok=1
      fi
      if "$CLI" dump 2>&1 | grep -qE '\[AXButton\] desc=(Computer|Control browser) title=- val=On'; then
        echo "FAIL  an agent mode is ON, it spends paid credits; switch to Search"; ok=1
      else
        echo "PASS  no credit-spending mode is active"
      fi
      ;;
    browser)
      echo "INFO  browser path: this script cannot test it, because the browser is driven"
      echo "      by the agent's own automation. Check it by opening perplexity.ai in a new"
      echo "      tab and confirming the composer is in Search mode before the first ask." ;;
    *)
      echo "INFO  no path recorded yet, ask the user which they prefer, then --path" ;;
  esac
  return $ok
}

CHOICE=""
DO_INSTALL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --path)
      [ $# -ge 2 ] || { echo "--path takes 'app' or 'browser'" >&2; exit 1; }
      CHOICE="$2"; shift 2 ;;
    --install-cli) DO_INSTALL=1; shift ;;
    --doctor) doctor; exit $? ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1"; exit 1 ;;
  esac
done

[ "$DO_INSTALL" = 1 ] && install_cli

if [ -n "$CHOICE" ]; then
  case "$CHOICE" in
    app)
      if [ "$PLATFORM" != "macos" ]; then
        echo "The app path cannot run on this platform: it drives the macOS desktop app"
        echo "through the macOS accessibility API. Use: $0 --path browser"
        exit 1
      fi
      find_app >/dev/null || echo "NOTE: the Perplexity app was not found in /Applications."
      find_cli >/dev/null || echo "NOTE: the desktop helper is not installed yet, run with --install-cli."
      write_config app ;;
    browser)
      write_config browser ;;
    *) echo "--path takes 'app' or 'browser'"; exit 1 ;;
  esac
  exit 0
fi

report
