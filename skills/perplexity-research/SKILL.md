---
name: perplexity-research
description: Ask Perplexity a research question from inside a Claude session and get the sourced answer back — through the Perplexity desktop app or through a browser, whichever the user prefers. Use for "ask Perplexity", "research this with sources", "check this claim", "what do practitioners actually say", "get me citations", or whenever an answer needs sources the model cannot supply from memory.
---

# Perplexity research — ask from the session, get sources back

Runs on the user's own Perplexity account. Costs nothing beyond what a plain
search on that account already costs. Setup details and troubleshooting:
`references/SETUP.md`.

Ask questions the way a person would, and report answers back in plain English.
Detail is for when detail changes something, not a default setting.

## Pick the path once, then remember it

1. Read the config file first:
   `"${XDG_CONFIG_HOME:-$HOME/.config}"/perplexity-research-skill/config`.
   If it names a path, use that path and skip to "Ask a question".
2. If there is no config, check the platform first — `scripts/pplx-setup.sh`
   (or `scripts/pplx-setup.ps1` on Windows without bash) prints it and says
   which paths exist here. **On anything but macOS the browser is the only
   path**, so say that and use it rather than asking a question with one
   possible answer.
3. On macOS, ASK the user which they prefer, in one short question. **Offer the
   desktop app first and recommend it** — it is the better path and the
   intended default:
   - **Desktop app (recommended)** — runs in the background while they keep
     working: no window steals focus, nothing types into their screen. Needs
     macOS, the Perplexity app, a one-time helper install, and one
     accessibility permission click.
   - **Browser** — the fallback, for when the app path is not possible: not
     macOS, the app is not installed, or the user says they want the browser.
     It works anywhere but drives a real browser window, so it collides with
     what the user is doing in that browser.
   Wait for their answer. Never pick for them, and never quietly settle on the
   browser because it looks easier to set up.
4. Save the answer so the question is asked once:
   `scripts/pplx-setup.sh --path app|browser`, or on Windows
   `scripts/pplx-setup.ps1 -Path browser`. The script checks what is actually
   installed, reports what is missing, and writes the config. With no usable
   shell at all, write the config file yourself — it is two lines, `path=app`
   or `path=browser` under a comment.
5. Re-ask only when the chosen path fails twice in a row, and offer the other
   one rather than retrying a third time.

## Ask a question

6. **Ask it the way a person would.** Write the question you would put to a
   well-read colleague: plain words, one clear ask, no preamble. Length is not
   rigour — an over-specified question comes back padded and harder to check.
7. Add a detail only when it changes the answer: a timeframe, a place, a field,
   or who you want to hear from (practitioners rather than vendors, say). Skip
   role-play framing, formatting demands, and restating the obvious.
8. Ask for sources when the answer will be used for something — who said it,
   where, and when. That is the one demand always worth its words, because an
   uncited answer cannot be checked.
9. **Write the answer back in plain English.** Say what it means in ordinary
   words. Spell out an acronym or a technical term the first time it appears,
   and say what a number actually measures rather than quoting it bare. If a
   reader outside the field would stall on a sentence, rewrite it.
10. Keep it short by leaving things out, not by compressing sentences into
   fragments, arrows, or shorthand. A few plain sentences beat a wall of
   bullets; paste the whole thread only when someone needs the whole thread.
11. **App path:** run `scripts/pplx-ask.sh "your question" [max_wait_seconds]`.
    It sets the composer, submits, waits for the answer to finish, and prints
    it. It never types keystrokes, never activates the app, and never touches
    the clipboard, so the user can keep working while it runs.
12. **Browser path:** drive `https://www.perplexity.ai` with whatever browser
    automation this session has. Open a new tab rather than reusing one the
    user is working in. Type into the composer, submit with the composer's own
    submit button, then poll until the answer stops growing before reading it.
13. **Treat every claim as a claim, not a fact.** Open the source and check it
    actually says what the answer says it says. Research tools as a class have
    been measured citing sources that do not support the claim, so this is the
    step that makes the sourcing worth anything.

## Choose the mode and the model on purpose

Leaving everything on auto wastes a strong model on trivia and sends a hard
question to a fast one. Choose deliberately — but choose from what this account
actually offers today.

14. **Read the lineup, never hardcode it.** Run `scripts/pplx-modes.sh --models`
    and pick from what it prints. Perplexity's own documentation says the model
    selector in the app is the source of truth for an account, because models are
    added and retired continuously — so any list written into a skill file is
    wrong within weeks, and wrong in a way that reads as authoritative.
15. **Route on the axes that survive renames, not on names.** Three have held
    across every lineup change:
    - **Mode** — Search or Deep Research. This changes the answer far more than
      swapping one frontier model for another, so spend the decision here first.
    - **Thinking** — a setting on a model, not a separate model. Some models
      have it always on, some optional, some not at all.
    - **Provider family** — only when it genuinely matters, which is mainly
      disagreement (below).
16. **Match the task class to those axes:**
    - A single fact, a date, a version, "does X exist" → Search, Thinking off,
      the automatic default. Never Deep Research.
    - Synthesis, comparisons, tradeoffs → Search with Thinking on; Deep Research
      only if the deliverable really is a report.
    - Code, stack traces, API behavior → Search with Thinking on.
    - A checked claim — a vendor statistic, "did they really say that", anything
      someone wants to be true → **ask the same question of two models from
      different providers and compare the answers.** A single confident report is
      the worst tool here, because it launders weak sources into fluent prose.
    - A long document or uploaded file → the mode that accepts documents, and
      mind that file uploads are metered separately.
17. **When the model you wanted is not in the picker, fall back to the automatic
    option and say so.** Never substitute a guessed name: a name that no longer
    exists selects nothing, and a silent fallback turns a "deep" request into a
    fast answer nobody notices.
18. **Never select a tier-gated row.** Pickers list models above the current plan
    to advertise them. Selecting one is an upgrade prompt, not a capability.
19. **Put the picker back** to what it was. A person shares this account.
20. **Deep Research is chosen by the shape of the deliverable** — a multi-section
    report someone will read and cite — not by how hard the question feels. A
    hard question with a one-line answer is still a Search. Permission to run one
    is covered below, under money.

## The user's account is theirs — never handle it

The user connects Perplexity themselves by signing in to the app or the browser,
once, by hand. There is nothing for this skill to authenticate.

- Never ask the user for a Perplexity password, and refuse it if offered.
- Never try to sign in, sign up, or create an account on their behalf.
- Never read, copy, store, or transmit session cookies or auth tokens. Reading
  the answer out of an app the user is already signed in to is the whole method;
  extracting their session is a different thing and is out of bounds.
- If the app or page is signed out, say so and ask the user to sign in
  themselves. Do not work around it.
- Store nothing about the user beyond the two-line path config.

## Never spend the user's money

21. Use plain Search mode. Before submitting in a browser, confirm the composer
    is in Search mode — some Perplexity composers default to an agent mode that
    consumes paid credits.
22. Abort and report if a submission lands on a URL containing `/computer/`, or
    on any other agent-mode session. Do not retry it.
23. Never click "Add credits", never start a subscription or upgrade flow, and
    never select a mode or model marked as a higher tier than the user's plan.
    Those are the user's purchasing decisions, not the session's.
24. Deep Research draws on a quota the user shares with their own usage, and
    consumer plans do not publish how much of it is left — so neither the session
    nor the user can measure it. Say you are about to run one and get a yes
    first. Plain searches need no permission.

## Never leak the user's data

25. A question is an outbound message. Never put credentials, API keys, private
    customer records, contract terms, or anything under an agreement into one.
26. Before pointing Perplexity's folder or file context at a directory, check
    what is in that directory. Point it at a purpose-built folder holding only
    material that is safe to share, never at a whole working repository, which
    normally holds keys and private files.
27. Leave the account as you found it: delete throwaway test threads, and if
    you change the model or mode selector, set it back.

## When it does not work

28. App path, nothing comes back: run the helper's dump command and look for
    the answer text in the accessibility tree. `references/SETUP.md` has the
    exact commands and the known failure shapes.
29. Browser path, the answer looks truncated: the page streams, so poll until
    the text stops changing rather than reading once.
30. Either path, twice failed: tell the user plainly what failed and offer the
    other path. Do not keep retrying the same broken route.
