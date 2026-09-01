# Perplexity research — instructions for coding agents

This repository is a Claude Code skill, but nothing in it is Claude-specific:
the working parts are plain bash scripts with no SDK and no API key. Codex, or
any agent that can run a shell command, can use it by following this file.

`skills/perplexity-research/SKILL.md` is the full rule set. This page is the
short version plus the notes that matter to a non-Claude agent.

## What it does

Asks the user's own Perplexity account a research question and returns the
sourced answer into the session, without the user copying anything between
windows. It uses their existing subscription — no paid API key, and it refuses
to touch anything that spends credits.

## Use it

```bash
# 1. What is available on this machine? (read-only; also prints which path to recommend)
skills/perplexity-research/scripts/pplx-setup.sh

# 2. Ask the user which path they want — OFFER THE APP FIRST — then record it
skills/perplexity-research/scripts/pplx-setup.sh --path app      # recommended default (macOS)
skills/perplexity-research/scripts/pplx-setup.sh --path browser  # fallback, any OS

# 2b. Prove it actually works before the first question
skills/perplexity-research/scripts/pplx-setup.sh --doctor

# 3. See the current modes, and what models this account can pick today
skills/perplexity-research/scripts/pplx-modes.sh --models

# 4. Ask (app path)
skills/perplexity-research/scripts/pplx-ask.sh "your question" 180
```

On the browser path there is no script to run: drive `https://www.perplexity.ai`
with whatever browser automation the agent has, in a new tab, and follow the
same rules.

## Rules an agent must not break

- **Ask which path the user prefers before setting one, and offer the desktop
  app first.** It is the intended default because it runs in the background
  instead of taking over a browser window the person is using. The browser path
  is the fallback for machines that cannot run the app. Do not pick for them, and
  do not settle on the browser just because it needs no install.
- **Plain Search only.** Never select an agent mode (variously "Computer",
  "Control browser"). They spend paid credits. The app-path script refuses to
  submit when one is active; on the browser path, check the mode control's state
  yourself before submitting, and abort on any URL containing `/computer/`.
- **Never click a purchase control** — add credits, upgrade, subscribe — and
  never select a model or mode gated to a higher plan than the user's.
- **Ask before Deep Research.** It draws a daily quota the user shares with
  their own usage. Plain searches need no permission.
- **Choose the model deliberately, from what exists today.** Run the modes script
  with `--models` and route on axes that survive renames: mode (Search vs Deep
  Research), whether reasoning/"Thinking" is on, and provider family. For a claim
  someone wants to be true, ask two models from different providers and compare.
  Never hardcode a model name: the lineup changes continuously, and the account's
  own picker is the only source of truth. If a wanted model is absent, fall back
  to the automatic option and SAY so — never substitute a guess, and never let a
  failed selection pass silently.
- **Nothing private goes into a question.** It is an outbound message.
- **The account is the user's to connect.** They sign in to the app or browser by
  hand, once. Never ask for their password, never sign in for them, and never
  read, store, or transmit session cookies or auth tokens. If it is signed out,
  ask them to sign in themselves.
- **Leave the account as you found it** — reset any picker you changed, and
  delete throwaway test threads.

## Exit codes from `pplx-ask.sh`

| Code | Meaning |
|---|---|
| 0 | answer printed on stdout |
| 1 | setup problem — helper missing, app has no window, composer unreachable |
| 2 | the answer did not finish inside the wait window; the thread still exists in the app |
| 3 | refused: an agent mode that spends credits was active |

Treat 3 as a stop, not a retry. Treat 2 as "check back", not a failure.
