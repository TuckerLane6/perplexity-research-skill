# Perplexity research skill for Claude Code and Codex

Ask Perplexity a research question from inside a coding session and get the
sourced answer back in the transcript — no copy-paste between windows.

It runs on **your own Perplexity subscription**. There is no API key. Plain
searches cost nothing beyond the plan you already pay for, and anything that
would spend credits stops and asks you first. The default is the **desktop app**,
driven in the background so it never takes over your screen; a **browser** path
is the fallback for machines that cannot run the app.

Works on **macOS, Windows and Linux**, and in Claude Code, Codex, or any other
agent that can run a shell command — see [AGENTS.md](AGENTS.md).

| Platform | Path | Setup |
|---|---|---|
| macOS | desktop app (default) or browser | `pplx-setup.sh` |
| Windows | browser | `pplx-setup.ps1` (PowerShell 5.1+), or `pplx-setup.sh` in Git Bash / WSL |
| Linux | browser | `pplx-setup.sh` |

The desktop path drives the macOS app through the macOS accessibility API, so it
is macOS-only by nature. Everywhere else the browser path does the same job with
whatever browser automation the agent already has, and the scripts say so rather
than failing halfway through.

## Install

macOS and Linux:

```bash
git clone https://github.com/TuckerLane6/perplexity-research-skill.git
cp -r perplexity-research-skill/skills/perplexity-research ~/.claude/skills/
chmod +x ~/.claude/skills/perplexity-research/scripts/*.sh
```

Windows (PowerShell):

```powershell
git clone https://github.com/TuckerLane6/perplexity-research-skill.git
Copy-Item -Recurse perplexity-research-skill\skills\perplexity-research $HOME\.claude\skills\
```

**Using Codex or another agent instead?** There is no skills folder to copy into.
Clone the repo anywhere and point the agent at [AGENTS.md](AGENTS.md); the scripts
are plain shell and run from wherever the clone lives.

Then ask for research in a session:

> ask Perplexity what practitioners actually say about X, with sources

On macOS the skill asks once which path you want, offering the app first, and
records your answer in `~/.config/perplexity-research-skill/config`. On Windows
and Linux there is only one workable path, so it says so and uses the browser
rather than asking a question with a single possible answer.

Run the scripts from the skill directory:

```bash
cd ~/.claude/skills/perplexity-research

scripts/pplx-setup.sh                # what this machine can run
scripts/pplx-setup.sh --install-cli  # build the desktop helper (macOS; needs Go + git)
scripts/pplx-setup.sh --path app     # record the choice
scripts/pplx-setup.sh --doctor       # prove the path works right now
scripts/pplx-modes.sh --models       # current modes + the models this account offers
scripts/pplx-ask.sh "your question"  # ask (macOS app path)
```

On Windows, the same two setup steps in PowerShell:

```powershell
cd $HOME\.claude\skills\perplexity-research
scripts\pplx-setup.ps1                  # what this machine can run
scripts\pplx-setup.ps1 -Path browser    # record the choice
scripts\pplx-setup.ps1 -Doctor          # check it
```

Asking itself then happens through the browser your agent already drives, so
there is no ask script to run on Windows or Linux.

## How your Perplexity account gets connected

**You connect it once, by hand, the normal way. The skill never handles your
account at all.**

There is no API key to paste, no token to generate, no OAuth screen, and nothing
to configure. You sign in to Perplexity the same way you already do:

- **App path** — open the Perplexity desktop app and sign in, once. The skill
  drives that already-signed-in app.
- **Browser path** — be signed in to perplexity.ai in the browser your agent
  automates. The skill uses the session already sitting in that browser.

That is the whole connection story. Concretely, the skill:

- **never asks you for your password**, and will refuse if you offer it
- **never signs in on your behalf**, or creates an account for you
- **never reads, copies, or stores session cookies or auth tokens** — several
  other Perplexity integrations work by exporting your session token to a config
  file; this one does not, and cannot, because it never touches them
- **stores nothing about you.** The only file it writes is a two-line config
  recording which path you chose and where the helper lives

Whichever plan you are on is simply the plan it uses. Free, Pro, Max, Enterprise
— the skill reads what your account offers and works within it. If you are not
signed in, it tells you to sign in yourself rather than trying to do it for you;
`--doctor` reports that state explicitly.

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

**They spend money without asking.** The official server bills every call to your
API key. This skill has no API-key code path at all. Plain search is free beyond
your plan. The paid modes are still available to you — but the skill stops before
using one, tells you what it is and that it spends credits, and waits for you to
say yes in the conversation. A yes covers that one run, not the rest of the
session. It never touches a purchase control at all: spending credits you hold is
your call, buying more is not something a session should ever do for you.

**They stomp your clipboard, or your browser session.** The app path reads
answers out of the accessibility tree without touching the clipboard. When an
answer is too long for the tree to hold, it borrows the clipboard for about a
second, verifies the copied text actually belongs to the answer just asked, and
puts your previous clipboard straight back. If the copy does not match, it is
discarded and the answer is marked truncated rather than handing you text from
some other thread.

## What it will not do

- **Spend anything without asking.** No API key. Plain Search runs freely because
  it is already covered by your plan. Deep Research draws a quota you cannot
  measure, and agent modes spend real credits — both stop and ask, every time,
  and a yes applies to that run only. It never clicks add-credits, upgrade or
  subscribe under any circumstances, and never selects a model gated above your
  plan.
- **Leak your files.** A question is an outbound message: credentials, keys,
  private records and material under agreement stay out. If you want local
  context, point the app at a folder built for sharing, never at a whole repo.
- **Take over your session.** No keystrokes, no window activation, no clipboard
  writes on the normal path; the browser path opens its own tab.
- **Pass off unsourced text as research.** If the answer has no sources panel, it
  says so and tells you not to quote it onward.

## Limits worth knowing

- **The app path is macOS only.** The helper drives the desktop app through the
  macOS accessibility API. On Windows and Linux the browser path does the same
  job, and the setup scripts detect the platform and say so rather than offering
  a choice that cannot work.
- **A very long answer can still come back marked truncated.** The app renders
  its answer lazily, so the accessibility tree sometimes holds only the first
  part. The script waits for the text to stop growing, and if it still looks
  unfinished it borrows the clipboard for about a second — putting back whatever
  was there — and accepts the copy only when it matches the thread it just asked
  about. When it cannot confirm that, it labels the answer TRUNCATED instead of
  guessing. A narrower question is the surest fix.
- **One question at a time.** The app is a single shared surface. Two asks
  running at once would read each other's threads, so there is no parallelism
  here by design.
- **A run occasionally needs a retry.** Driving a native app through the
  accessibility API is not a transaction: a submit can miss, or the answer can
  still be generating when the wait runs out. It fails loudly with an exit code
  rather than inventing an answer, and it never hands you another thread's text.
  Retry once; if it fails twice, switch to the browser path.
- **Quotas move without warning.** Consumer plans do not publish how much Deep
  Research budget is left, and published limits have been cut mid-subscription
  before. Treat it as scarce and unmeasurable.

## A note on automating a service you log into

Perplexity's terms restrict automated access to the service. This skill drives
the app you already have open, under your own login, one question at a time, at
human pace — a materially different thing from exporting your session cookies or
scraping headlessly, but it is not nothing. Read the terms and make your own
call.

## Requirements

- Claude Code, Codex, or any agent that can run a shell command
- A Perplexity account (no API key, no paid API)
- App path: macOS, the Perplexity desktop app, Go and git to build the helper
- Browser path: any browser automation your session already has. Nothing to
  install and nothing to build; if a machine has no usable shell, the config is
  a two-line text file you can write by hand

## Credits

The desktop path builds on [pplx-cli](https://github.com/toby1991/pplx-cli), an
open-source macOS helper that drives the Perplexity app through the accessibility
API. Depending on your app version it may need its bundle identifier and URL
scheme updated before it works; [SETUP.md](skills/perplexity-research/references/SETUP.md)
explains how to check, and lists the failure shapes found while building it.

## License

MIT — see [LICENSE](LICENSE).
