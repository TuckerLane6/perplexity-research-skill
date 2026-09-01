# Perplexity research skill for Claude Code and Codex

Ask Perplexity a research question from inside a coding session and get the
sourced answer back in the transcript, without copy-pasting between windows.

It runs on your own Perplexity subscription. There is no API key. Plain searches
cost nothing beyond the plan you already pay for, and anything that would spend
credits stops and asks you first: the ask script refuses to submit unless it can
confirm the composer is on the free Search mode. The desktop app is the default
path, driven in the background so it never takes over your screen. A browser path
covers machines that cannot run the app.

Works on macOS, Windows and Linux, and in Claude Code, Codex, or any other agent
that can run a shell command. See [AGENTS.md](AGENTS.md).

| Platform | Path | Setup |
|---|---|---|
| macOS | desktop app (default) or browser | `pplx-setup.sh` |
| Windows | browser | `pplx-setup.ps1` (PowerShell 5.1+), or `pplx-setup.sh` in Git Bash / WSL |
| Linux | browser | `pplx-setup.sh` |

The desktop path drives the macOS app through the macOS accessibility API, so it
only runs on macOS. Everywhere else the browser path does the same job with
whatever browser automation the agent already has, and the scripts say so instead
of failing halfway through.

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

Codex and other agents have no skills folder to copy into. Clone the repo
anywhere and point the agent at [AGENTS.md](AGENTS.md). The scripts are plain
shell and run from wherever the clone lives.

Then ask for research in a session:

> ask Perplexity what practitioners actually say about X, with sources

On macOS the skill asks once which path you want, offering the app first, and
records your answer in `~/.config/perplexity-research-skill/config`. On Windows
and Linux only one path works, so it says so and uses the browser instead of
asking a question with a single possible answer.

Run the scripts from the skill directory:

```bash
cd ~/.claude/skills/perplexity-research

scripts/pplx-setup.sh                # what this machine can run
scripts/pplx-setup.sh --install-cli  # build the desktop helper (macOS; needs Go + git)
scripts/pplx-setup.sh --path app     # record the choice
scripts/pplx-setup.sh --doctor       # prove the path works right now
scripts/pplx-modes.sh --models       # current modes, and the models this account offers
scripts/pplx-ask.sh "your question"  # ask (macOS app path)
```

The same two setup steps in PowerShell:

```powershell
cd $HOME\.claude\skills\perplexity-research
scripts\pplx-setup.ps1                  # what this machine can run
scripts\pplx-setup.ps1 -Path browser    # record the choice
scripts\pplx-setup.ps1 -Doctor          # check it
```

On Windows and Linux the asking happens through the browser your agent already
drives, so there is no ask script to run.

## How your Perplexity account gets connected

You connect it once, by hand, the normal way. The skill never handles your
account.

There is no API key to paste, no token to generate, no OAuth screen, and nothing
to configure. You sign in to Perplexity the same way you already do. On the app
path, open the Perplexity desktop app and sign in once, and the skill drives that
signed-in app. On the browser path, be signed in to perplexity.ai in the browser
your agent automates, and the skill uses the session already sitting there.

That is the whole connection story. The skill never asks for your password, and
will refuse it if you offer. It never signs in for you or creates an account. It
never reads, copies, or stores session cookies or auth tokens: several other
Perplexity integrations work by exporting your session token to a config file,
and this one cannot, because it never touches them. In normal use the only file
it writes is a two-line config recording which path you chose and where the
helper lives. The one exception is `--install-cli`, which you run deliberately:
it clones the helper into a temporary directory and builds a binary into
`~/.local/bin`.

Whichever plan you are on is the plan it uses. Free, Pro, Max and Enterprise all
work, because the skill reads what your account offers and stays inside it. If
you are not signed in, it tells you to sign in yourself rather than trying to do
it for you, and `--doctor` reports that state.

## How this differs from the other Perplexity integrations

Most of what exists is an MCP server that calls Perplexity's paid API with an API
key, so every question is billed separately from the subscription you already pay
for. The rest drive the web UI with exported session cookies or headless
browsers. Four problems repeat across both groups.

**They hardcode model names, and the names die.** Popular projects still ship
lists naming models retired one or two generations ago. Perplexity's own help
center says the model selector in your account is the source of truth, because
models are added and retired continuously. This skill reads the picker at runtime
and hands the agent what is there today.

**They default to auto, or fall back silently.** One popular project admits it
drops to standard mode when it cannot find the toggle, so a "deep research"
request quietly returns a five-second answer. Here, a model that cannot be
selected becomes a stated fallback with a note, never a silent downgrade.

**They spend money without asking.** The official server bills every call to your
API key. This skill has no API-key code path at all. Plain search is free beyond
your plan. The paid modes are still available to you, but the skill stops before
using one, tells you what it is and that it spends credits, and waits for you to
say yes in the conversation. A yes covers that one run, not the rest of the
session. It never touches a purchase control: spending credits you hold is your
call, and buying more is not something a session should do for you.

**They stomp your clipboard, or your browser session.** The app path reads
answers out of the accessibility tree without touching the clipboard. When an
answer is too long for the tree to hold, it borrows the clipboard for about a
second, checks that the copied text belongs to the answer it just asked about,
and puts your previous clipboard straight back. If the copy does not match, it
gets discarded and the answer is marked truncated, rather than handing you text
from some other thread.

## What it will not do

It will not spend anything without asking. Plain search runs freely because your
plan already covers it. Deep Research draws a quota you cannot measure, and agent
modes spend real credits, so both stop and ask every time, and a yes applies to
that run only. It never clicks add-credits, upgrade or subscribe under any
circumstances, and never selects a model gated above your plan.

It will not leak your files. A question is an outbound message, so credentials,
keys, private records and material under agreement stay out of it. If you want
local context, point the app at a folder built for sharing rather than at a whole
repo.

It will not take over your session. No keystrokes and no window activation. It
leaves the clipboard alone except in one case: recovering a long answer the app
truncated, where it borrows the clipboard for about a second and puts the
previous contents straight back. The browser path opens its own tab.

It will not pass off unsourced text as research. If an answer has no sources
panel, the skill says so and tells you not to quote it onward.

## Limits worth knowing

**The app path is macOS only.** The helper drives the desktop app through the
macOS accessibility API. On Windows and Linux the browser path does the same job,
and the setup scripts detect the platform and say so instead of offering a choice
that cannot work.

**A very long answer can still come back marked truncated.** The app renders its
answer lazily, so the accessibility tree sometimes holds only the first part. The
script waits for the text to stop growing, and if it still looks unfinished it
borrows the clipboard for about a second, putting back whatever was there, and
accepts the copy only when it matches the thread it just asked about. When it
cannot confirm that, it labels the answer TRUNCATED instead of guessing. A
narrower question is the surest fix.

**One question at a time.** The app is a single shared surface. Two asks running
at once would read each other's threads, so there is no parallelism here.

**A run occasionally needs a retry.** Driving a native app through the
accessibility API is not a transaction: a submit can miss, or the answer can
still be generating when the wait runs out. It fails loudly with an exit code
instead of inventing an answer, and it never hands you another thread's text.
Retry once, and if it fails twice, switch to the browser path.

**Quotas move without warning.** Consumer plans do not publish how much Deep
Research budget is left, and published limits have been cut mid-subscription
before. Treat it as scarce and unmeasurable.

## How much of this is enforced

Worth being precise, because the difference matters if you are handing an agent
your subscription. The mode check is enforced in code: the ask script reads the
composer's own state and exits rather than submitting when it cannot confirm the
free mode. The approval itself is not enforceable from a script. `--credits-approved`
is a flag the agent passes, and nothing but the agent's instructions stops it
passing that flag without asking you. Treat the gate as a strong default and a
clear instruction, not as a lock, and read what your agent tells you before you
say yes.

## A note on automating a service you log into

Perplexity's terms restrict automated access. This skill drives the app you
already have open, under your own login, one question at a time, at human pace.
That is different from exporting your session cookies or scraping headlessly, but
it is not nothing. Read the terms and make your own call.

## Requirements

You need Claude Code, Codex, or any agent that can run a shell command, plus a
Perplexity account. No API key and no paid API.

The app path needs macOS, the Perplexity desktop app, and Go and git to build the
helper. The browser path needs whatever browser automation your session already
has, with nothing to install or build. If a machine has no usable shell, the
config is a two-line text file you can write by hand.

## Credits

The desktop path builds on [pplx-cli](https://github.com/toby1991/pplx-cli), an
open-source macOS helper that drives the Perplexity app through the accessibility
API. Depending on your app version it may need its bundle identifier and URL
scheme updated first.
[SETUP.md](skills/perplexity-research/references/SETUP.md) explains how to check,
and lists the failure shapes found while building this.

## License

MIT. See [LICENSE](LICENSE).
