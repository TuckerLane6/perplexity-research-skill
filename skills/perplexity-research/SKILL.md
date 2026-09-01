---
name: perplexity-research
description: Ask Perplexity a research question from inside a Claude session and get the sourced answer back — through the Perplexity desktop app or through a browser, whichever the user prefers. Use for "ask Perplexity", "research this with sources", "check this claim", "what do practitioners actually say", "get me citations", or whenever an answer needs sources the model cannot supply from memory.
---

# Perplexity research — ask from the session, get sources back

Runs on the user's own Perplexity account. Costs nothing beyond what a plain
search on that account already costs. Setup details and troubleshooting:
`references/SETUP.md`.

## Pick the path once, then remember it

1. Read the config file first:
   `"${XDG_CONFIG_HOME:-$HOME/.config}"/perplexity-research-skill/config`.
   If it names a path, use that path and skip to "Ask a question".
2. If there is no config, ASK the user which they prefer, in one short
   question, and say what each costs them:
   - **Desktop app** — runs in the background while they keep working, needs
     the Perplexity macOS app plus a one-time helper install and one
     accessibility permission click. macOS only.
   - **Browser** — works on any operating system with any browser automation
     the session already has, but it drives a real browser window, so it can
     collide with what the user is doing in that browser.
   Wait for the answer. Never pick for them.
3. Save the answer so the question is asked once:
   `scripts/pplx-setup.sh --path app` or `scripts/pplx-setup.sh --path browser`.
   The script checks what is actually installed, reports what is missing, and
   writes the config.
4. Re-ask only when the chosen path fails twice in a row, and offer the other
   one rather than retrying a third time.

## Ask a question

5. Write the question so the answer can be graded: ask for verbatim quotes,
   who said them, the URLs, and the dates. An uncited answer cannot be checked
   and should not be quoted onward as fact.
6. **App path:** run `scripts/pplx-ask.sh "your question" [max_wait_seconds]`.
   It sets the composer, submits, waits for the answer to finish, and prints
   it. It never types keystrokes, never activates the app, and never touches
   the clipboard, so the user can keep working while it runs.
7. **Browser path:** drive `https://www.perplexity.ai` with whatever browser
   automation this session has. Open a new tab rather than reusing one the
   user is working in. Type into the composer, submit with the composer's own
   submit button, then poll until the answer stops growing before reading it.
8. Treat every returned claim as a claim, not a fact: check the citation
   exists and says what the answer says it says, before acting on it.

## Never spend the user's money

9. Use plain Search mode. Before submitting in a browser, confirm the composer
   is in Search mode — some Perplexity composers default to an agent mode that
   consumes paid credits.
10. Abort and report if a submission lands on a URL containing `/computer/`, or
    on any other agent-mode session. Do not retry it.
11. Never click "Add credits", never start a subscription or upgrade flow, and
    never select a mode or model marked as a higher tier than the user's plan.
    Those are the user's purchasing decisions, not the session's.
12. Deep Research draws on a daily quota the user shares with their own usage.
    Say you are about to run one and get a yes first. Plain searches need no
    permission.

## Never leak the user's data

13. A question is an outbound message. Never put credentials, API keys, private
    customer records, contract terms, or anything under an agreement into one.
14. Before pointing Perplexity's folder or file context at a directory, check
    what is in that directory. Point it at a purpose-built folder holding only
    material that is safe to share, never at a whole working repository, which
    normally holds keys and private files.
15. Leave the account as you found it: delete throwaway test threads, and if
    you change the model or mode selector, set it back.

## When it does not work

16. App path, nothing comes back: run the helper's dump command and look for
    the answer text in the accessibility tree. `references/SETUP.md` has the
    exact commands and the known failure shapes.
17. Browser path, the answer looks truncated: the page streams, so poll until
    the text stops changing rather than reading once.
18. Either path, twice failed: tell the user plainly what failed and offer the
    other path. Do not keep retrying the same broken route.
