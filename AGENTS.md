# Perplexity research, instructions for coding agents

This repository is a Claude Code skill, but nothing in it is Claude-specific:
the working parts are plain bash scripts with no SDK and no API key. Codex, or
any agent that can run a shell command, can use it by following this file.

`skills/perplexity-research/SKILL.md` is the full rule set. This page is the
short version plus the notes that matter to a non-Claude agent.

## What it does

Asks the user's own Perplexity account a research question and returns the
sourced answer into the session, without the user copying anything between
windows. It uses their existing subscription, no paid API key. Plain searches
are free beyond that plan; anything that would spend credits stops and asks the
user first, and proceeds only on an explicit yes to that run.

## Use it

```bash
# 1. What is available on this machine? (read-only; also prints which path to recommend)
skills/perplexity-research/scripts/pplx-setup.sh

# 2. Ask which path they want, OFFERING THE APP FIRST, then record it
skills/perplexity-research/scripts/pplx-setup.sh --path app      # recommended default (macOS)
skills/perplexity-research/scripts/pplx-setup.sh --path browser  # fallback, any OS

# 2b. Prove it actually works before the first question
skills/perplexity-research/scripts/pplx-setup.sh --doctor

# 3. See the current modes and models (app path only; needs the macOS helper)
skills/perplexity-research/scripts/pplx-modes.sh --models

# 4. Ask (app path)
skills/perplexity-research/scripts/pplx-ask.sh "your question" 180
```

On the browser path there is no script to run: drive `https://www.perplexity.ai`
with whatever browser automation the agent has, in a new tab, and follow the
same rules.

**Platforms.** macOS gets both paths and defaults to the app. Windows and Linux
get the browser path, which is not a downgrade in capability, only the app
automation is macOS-specific. On Windows use `scripts/pplx-setup.ps1 -Path
browser` (works on the PowerShell that ships with Windows), or the bash script
under Git Bash or WSL. With no shell at all, write the config file yourself at
`~/.config/perplexity-research-skill/config`: a comment line and `path=browser`.

## Rules an agent must not break

- **Ask which path the user prefers before setting one, and offer the desktop
  app first.** It is the intended default because it runs in the background
  instead of taking over a browser window the person is using. The browser path
  is the fallback for machines that cannot run the app. Do not pick for them, and
  do not settle on the browser just because it needs no install.
- **Money is a gate, not a ban.** Plain Search is free beyond the user's plan and
  needs no permission. Deep Research spends an unmeasurable quota, and agent modes
  ("Computer", "Control browser") spend real credits. Before either, say what it
  is, that it costs, and what the run looks like, then wait for an explicit yes.
  A yes covers that one run only. The app script stops when a paid mode is active
  and proceeds only with `--credits-approved`, which you may pass only after that
  yes. On the browser path, check the mode control yourself before submitting.
- **Never click a purchase control**, add credits, upgrade, subscribe, or enter
  payment details, even when the user has approved a paid run, and even if a task
  stalls for want of balance. Spending held credits is theirs to approve; buying
  more is a decision they make outside the session. Never select a model or mode
  gated above their plan.

- **Choose the model deliberately, from what exists today.** Run the modes script
  with `--models` and route on axes that survive renames: mode (Search vs Deep
  Research), whether reasoning/"Thinking" is on, and provider family. For a claim
  someone wants to be true, ask two models from different providers and compare.
  Never hardcode a model name: the lineup changes continuously, and the account's
  own picker is the only source of truth. If a wanted model is absent, fall back
  to the automatic option and SAY so, never substitute a guess, and never let a
  failed selection pass silently.
- **Nothing private goes into a question.** It is an outbound message.
- **The account is the user's to connect.** They sign in to the app or browser by
  hand, once. Never ask for their password, never sign in for them, and never
  read, store, or transmit session cookies or auth tokens. If it is signed out,
  ask them to sign in themselves.
- **Leave the account as you found it**, reset any picker you changed, and
  delete throwaway test threads.

## Exit codes from `pplx-ask.sh`

| Code | Meaning |
|---|---|
| 0 | answer printed on stdout |
| 1 | setup problem, helper missing, app has no window, composer unreachable |
| 2 | the answer did not finish inside the wait window; the thread still exists in the app |
| 3 | stopped before spending: either a credit-spending mode was active, or the free Search mode could not be confirmed. The message says which |

Treat 3 as "go ask the user", not a retry. If a paid mode was active: ask, and
re-run with `--credits-approved` if they agree, or switch the composer back to
Search. If the mode simply could not be confirmed, check the composer in the app
first; the same flag overrides it once you know what mode it is on. Treat 2 as "check back", not a failure.
