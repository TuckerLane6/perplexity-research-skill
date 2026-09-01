# Perplexity research skill for Claude Code

Ask Perplexity a research question from inside a Claude Code session and get the
sourced answer back in the transcript — no copy-paste between windows.

It runs on your own Perplexity account and asks you once whether you would
rather it drive the **desktop app** (macOS, runs in the background while you
keep working) or a **browser** (any operating system). It remembers the answer.

## Install

Copy the skill into your skills directory:

```bash
git clone https://github.com/<your-account>/perplexity-research-skill.git
cp -r perplexity-research-skill/skills/perplexity-research ~/.claude/skills/
chmod +x ~/.claude/skills/perplexity-research/scripts/*.sh
```

Then just ask for research in a session:

> ask Perplexity what practitioners actually say about X, with sources

The skill asks which path you prefer the first time, records the choice in
`~/.config/perplexity-research-skill/config`, and uses it from then on.

## The two paths

**Browser** — nothing to install. Works with whatever browser automation your
session already has. It drives a real browser window, so it can collide with
what you are doing in that browser.

**Desktop app** (macOS) — needs the Perplexity app plus a small open-source
helper built from source, and one Accessibility permission. In exchange it runs
completely in the background: it writes the question through the accessibility
API and reads the answer back the same way, with no keystrokes, no clipboard
writes, and no window stealing focus.

```bash
skills/perplexity-research/scripts/pplx-setup.sh              # what is available here
skills/perplexity-research/scripts/pplx-setup.sh --install-cli # build the helper (needs Go + git)
skills/perplexity-research/scripts/pplx-setup.sh --path app    # record the choice
skills/perplexity-research/scripts/pplx-ask.sh "your question"
```

## What it will not do

- **Spend money.** Plain Search only. It never opens an agent mode that consumes
  paid credits, never clicks "add credits", never starts an upgrade, and never
  selects a model or mode gated to a higher plan than yours. Deep Research draws
  on your daily quota, so it asks before running one.
- **Leak your files.** Questions are outbound messages, so credentials, keys,
  private records and material under agreement stay out of them. If you want the
  app to read local context, point it at a folder built for sharing, never at a
  whole working repository.
- **Take over your session.** On the app path it never types keystrokes, never
  writes your clipboard, and never activates the window. On the browser path it
  opens its own tab.

## Why the odd bits exist

Every rule in the skill came from something that actually broke: a progress line
returned as an answer, a question submitted into an agent mode that would have
spent credits, an answer that never appeared because the tool read stdout while
the data went to stderr. `skills/perplexity-research/references/SETUP.md` lists
the failure shapes and what to do about each one.

## Requirements

- Claude Code
- A Perplexity account (a paid plan is what makes the app path worthwhile;
  neither path uses the paid API)
- Browser path: any browser automation available to your session
- App path: macOS, the Perplexity desktop app, Go and git to build the helper

## Credits

The desktop path builds on [pplx-cli](https://github.com/toby1991/pplx-cli), an
open-source macOS helper that drives the Perplexity app through the accessibility
API. Depending on your app version it may need its bundle identifier and URL
scheme updated before it works; SETUP.md explains how to check.

## License

MIT — see [LICENSE](LICENSE).
