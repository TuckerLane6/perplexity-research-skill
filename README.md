# Perplexity research skill for Claude Code

Ask Perplexity a research question from inside a coding session and get the
sourced answer back in the transcript — no copy-paste between windows.

It runs on **your own Perplexity subscription**. There is no API key, and no code
path that can spend money. The default is the **desktop app**, driven in the
background so it never takes over your screen; a **browser** path is the fallback
for machines that cannot run the app.

Works in Claude Code as a skill, and in Codex or any other agent that can run a
shell command — see [AGENTS.md](AGENTS.md).

## Install

```bash
git clone https://github.com/<your-account>/perplexity-research-skill.git
cp -r perplexity-research-skill/skills/perplexity-research ~/.claude/skills/
chmod +x ~/.claude/skills/perplexity-research/scripts/*.sh
```

Then ask for research in a session:

> ask Perplexity what practitioners actually say about X, with sources

The first time, the skill asks which path you want — offering the app first —
records the answer in `~/.config/perplexity-research-skill/config`, and uses it
from then on.

```bash
scripts/pplx-setup.sh              # what this machine can run
scripts/pplx-setup.sh --install-cli # build the desktop helper (needs Go + git)
scripts/pplx-setup.sh --path app    # record the choice
scripts/pplx-setup.sh --doctor      # prove the path works right now
scripts/pplx-modes.sh --models      # current modes + the models this account offers
scripts/pplx-ask.sh "your question"
```

## How this differs from the other Perplexity integrations

Most of what exists is an MCP server that calls Perplexity's **paid API** with an
API key, so every question is billed separately from the subscription you already
pay for. The rest drive the web UI with exported session cookies or headless
browsers. Across both groups, four problems repeat:

**They hardcode model names, and the names die.** Popular projects still ship
lists naming models that were retired one or two generations ago. Perplexity's
own help center says the model selector in your account is the source of truth,
because models are added and retired continuously. This skill reads the picker at
runtime and hands the agent what is actually there today.

**They default to auto, or fall back silently.** At least one popular project
admits it drops to standard mode when it cannot find the toggle — so a "deep
research" request quietly returns a five-second answer. Here a model that cannot
be selected is a stated fallback with a note, never a silent downgrade.

**They can spend money.** The official server bills every call to your API key.
This skill has no API-key code path at all, refuses to submit when an agent mode
that consumes credits is active, and never touches a purchase control. Search and
Deep Research draw on subscription quota; only agent modes cost money, and this
skill will not start one.

**They stomp your clipboard, or your browser session.** The app path reads
answers out of the accessibility tree without touching the clipboard. When an
answer is too long for the tree to hold, it borrows the clipboard for about a
second, verifies the copied text actually belongs to the answer just asked, and
puts your previous clipboard straight back. If the copy does not match, it is
discarded and the answer is marked truncated rather than handing you text from
some other thread.

## What it will not do

- **Spend money.** No API key, plain Search by default, refuses to submit while
  an agent mode is active, never clicks add-credits or upgrade, never selects a
  model gated to a higher plan. Deep Research draws a quota you cannot measure on
  a consumer plan, so it asks first.
- **Leak your files.** A question is an outbound message: credentials, keys,
  private records and material under agreement stay out. If you want local
  context, point the app at a folder built for sharing, never at a whole repo.
- **Take over your session.** No keystrokes, no window activation, no clipboard
  writes on the normal path; the browser path opens its own tab.
- **Pass off unsourced text as research.** If the answer has no sources panel, it
  says so and tells you not to quote it onward.

## Limits worth knowing before you install

- **The app path is macOS only.** The helper drives the desktop app through the
  macOS accessibility API. Everywhere else, use the browser path.
- **Long answers can arrive truncated.** The app renders answers lazily, so the
  accessibility tree sometimes holds only the beginning. The script detects this
  and says so rather than pretending the fragment is the whole answer. Asking a
  narrower question is the reliable workaround.
- **One question at a time.** The app is a single shared surface; there is no
  parallelism here.
- **Automating a service you log into is your call to make.** Perplexity's terms
  restrict automated access to the service. This skill drives the app you already
  have open, under your own login, one question at a time, at human pace — which
  is a materially different thing from exporting session cookies or scraping
  headlessly, but it is not nothing. Read the terms and decide for yourself.
- **Quotas move without warning.** Consumer plans do not publish remaining Deep
  Research budget, and published limits have been cut mid-subscription before.
  Treat quota as scarce and unmeasurable.

## Requirements

- Claude Code, Codex, or any agent that can run a shell command
- A Perplexity account (no API key, no paid API)
- App path: macOS, the Perplexity desktop app, Go and git to build the helper
- Browser path: any browser automation your session already has

## Credits

The desktop path builds on [pplx-cli](https://github.com/toby1991/pplx-cli), an
open-source macOS helper that drives the Perplexity app through the accessibility
API. Depending on your app version it may need its bundle identifier and URL
scheme updated before it works; [SETUP.md](skills/perplexity-research/references/SETUP.md)
explains how to check, and lists the failure shapes we hit building this.

## License

MIT — see [LICENSE](LICENSE).
