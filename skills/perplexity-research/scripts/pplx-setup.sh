#!/usr/bin/env bash
# pplx-setup.sh — choose and record how this machine talks to Perplexity.
#
#   pplx-setup.sh                 # report what is available here, change nothing
#   pplx-setup.sh --path app      # record the desktop-app path
#   pplx-setup.sh --path browser  # record the browser path
#   pplx-setup.sh --install-cli   # build the desktop helper from source (needs Go + git)
#
# Writes: ${XDG_CONFIG_HOME:-$HOME/.config}/perplexity-research-skill/config
# Everything is per-machine. Nothing here is specific to any one user or repo.
set -uo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/perplexity-research-skill"
CONFIG="$CONFIG_DIR/config"
CLI_UPSTREAM="https://github.com/toby1991/pplx-cli"

find_cli() {
  if command -v pplx >/dev/null 2>&1; then command -v pplx; return 0; fi
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
  echo "Platform:        $(uname -s)"
  if APP=$(find_app); then echo "Perplexity app:  found at $APP"
  else echo "Perplexity app:  not found"; fi
  if CLI=$(find_cli); then echo "Desktop helper:  found at $CLI"
  else echo "Desktop helper:  not installed (build it with --install-cli, or use the browser path)"; fi
  if [ -f "$CONFIG" ]; then echo "Recorded path:   $(grep -E '^path=' "$CONFIG" | cut -d= -f2)"
  else echo "Recorded path:   none yet — ask the user which they prefer, then rerun with --path"; fi
}

write_config() {
  local choice="$1"
  mkdir -p "$CONFIG_DIR"
  {
    echo "# written by pplx-setup.sh — safe to edit or delete"
    echo "path=$choice"
    if [ "$choice" = "app" ] && CLI=$(find_cli); then echo "cli=$CLI"; fi
  } > "$CONFIG"
  echo "Recorded: path=$choice  ->  $CONFIG"
}

install_cli() {
  command -v go  >/dev/null 2>&1 || { echo "Go is required to build the helper. Install Go, then rerun."; exit 1; }
  command -v git >/dev/null 2>&1 || { echo "git is required to build the helper. Install git, then rerun."; exit 1; }
  [ "$(uname -s)" = "Darwin" ] || { echo "The desktop helper drives the macOS app and only builds on macOS. Use the browser path instead."; exit 1; }

  SRC="${TMPDIR:-/tmp}/pplx-cli-src"
  rm -rf "$SRC"
  git clone --depth 1 "$CLI_UPSTREAM" "$SRC" || { echo "clone failed"; exit 1; }
  mkdir -p "$HOME/.local/bin"
  ( cd "$SRC" && go build -o "$HOME/.local/bin/pplx" . ) || {
    echo "Build failed. The upstream helper may need its bundle id and URL scheme updated"
    echo "for your app version — see references/SETUP.md."
    exit 1; }
  echo "Built: $HOME/.local/bin/pplx"
  echo "macOS will ask for Accessibility permission the first time it drives the app."
  echo "Grant it under System Settings > Privacy & Security > Accessibility."
}

CHOICE=""
DO_INSTALL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --path) CHOICE="${2:-}"; shift 2 ;;
    --install-cli) DO_INSTALL=1; shift ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1"; exit 1 ;;
  esac
done

[ "$DO_INSTALL" = 1 ] && install_cli

if [ -n "$CHOICE" ]; then
  case "$CHOICE" in
    app)
      [ "$(uname -s)" = "Darwin" ] || echo "NOTE: the app path is macOS only; the browser path works everywhere."
      find_app >/dev/null || echo "NOTE: the Perplexity app was not found in /Applications."
      find_cli >/dev/null || echo "NOTE: the desktop helper is not installed yet — run with --install-cli."
      write_config app ;;
    browser)
      write_config browser ;;
    *) echo "--path takes 'app' or 'browser'"; exit 1 ;;
  esac
  exit 0
fi

report
