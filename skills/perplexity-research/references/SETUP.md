# Setup and troubleshooting

Two paths do the same job. **The desktop app is the default** — it runs in the
background while the person keeps working. The browser is the fallback for
machines that cannot run the app. The skill asks once and remembers the answer.

| | Desktop app | Browser |
|---|---|---|
| Operating system | macOS only | any |
| Extra install | Perplexity app + a small helper built from source | none beyond the browser automation the session already has |
| One-time permission | macOS Accessibility | whatever the browser tool asks for |
| Runs in background | yes, the person keeps working | no, it drives a visible browser |
| Use it when | the machine is a Mac (this is the default) | not macOS, no app installed, or the user asks for it |

## Connecting the account

Nothing to connect. The user signs in to Perplexity by hand, once, in the app or
the browser — exactly as they would to use it themselves. The skill then works
inside that signed-in session.

There is **no API key, no token, and no OAuth step**, on either path. That is a
deliberate design choice, not a missing feature:

- an API key would bill the user's card per question, separately from the
  subscription they already pay for;
- exporting a session token to a config file — how several other integrations
  work — copies the user's credentials out of the browser they belong to.

This skill does neither. It never asks for a password, never signs in for the
user, and never reads or stores cookies or tokens. If the app or page is signed
out, the correct behavior is to say so and let the user sign in.

Whatever plan the account has is what it uses. The available modes and models are
read from the account at runtime rather than assumed.

## Browser path

Nothing to install. The skill drives `https://www.perplexity.ai` with whatever
browser automation the session has — a browser MCP server, a CDP-based harness,
or a scripted browser.

Rules that matter more than the tool:

- Open a **new tab**. Reusing a tab the person is working in interrupts them,
  and two drivers in one window fight each other.
- **Confirm Search mode before submitting.** Some composers — project composers
  in particular — default to an agent mode that spends paid credits. Read the
  mode control's pressed state and only submit when Search is the active one.
- Submit with the composer's own submit button. A plain Return keypress does not
  reliably submit long questions, and in some contexts it moves the draft
  somewhere else instead of sending it.
- The answer **streams**. Poll until the text stops growing, then read it. One
  early read returns a half-written answer or a progress line.
- If the resulting URL contains `/computer/` or any other agent-session path,
  stop, do not retry, and tell the user.

## Desktop-app path

1. Install the Perplexity macOS app and sign in as the user, by hand. This is
   the only account step, and it is the user's to do.
2. Build the helper: `scripts/pplx-setup.sh --install-cli` (needs Go and git).
   It builds `pplx` into `~/.local/bin`.
3. Grant Accessibility permission when macOS asks: System Settings → Privacy &
   Security → Accessibility.
4. Record the choice: `scripts/pplx-setup.sh --path app`.
5. Ask: `scripts/pplx-ask.sh "your question"`.

The helper is a fork-friendly open-source tool
(`https://github.com/toby1991/pplx-cli`). The skill uses three of its
subcommands: `set-input` (write the composer's value directly), `click <accessibility description>`,
and `dump` (print the accessibility tree).

### If the build works but nothing happens

The upstream helper pins the app's bundle identifier and URL scheme, and both
have changed across app versions. Check the installed app's real bundle id:

```
osascript -e 'id of app "Perplexity"'
```

If it differs from the constant in the helper's source, update the constant and
rebuild. The same applies to the `perplexity-desktop://` style URL scheme.

### Known failure shapes

- **`dump` prints to stderr.** Always run it as `pplx dump 2>&1`. Reading only
  stdout returns nothing and looks like an empty answer.
- **A URL-scheme query runs invisibly.** Firing a question through the app's URL
  scheme creates the thread server-side, but the app window never navigates, so
  there is no answer text in the tree to read. Write into the composer instead.
- **The progress line is not the answer.** While it works, the app shows a
  status line that a naive reader will return as the result. The Copy button
  appearing is the reliable "finished" signal.
- **Return does not reliably submit.** Long questions typed into the composer
  and submitted with Return sometimes do nothing. Click the send arrow, whose
  accessibility description is `arrow-right` on some builds and `arrow-up` on
  others.
- **Escape opens a launcher overlay.** A stray Escape can leave the app showing
  an overlay panel, after which questions go nowhere. Send Escape twice to
  clear it, then retry.
- **The app can be running with no window.** "New Session" also exists as a menu
  item on some builds, so a click by that description can open a menu instead and
  leave the window dismissed — after which writing the question fails with a
  set-value error. The ask script detects this (window count zero, or no text
  area in the tree) and reopens the window with `open -g -a "Perplexity"`, which
  restores it *without* pulling focus away from whatever the person is doing.
- **Long answers can be truncated in the tree.** The app renders the answer
  lazily, so the accessibility tree may hold only its first lines. The ask script
  detects this (the text does not end on sentence punctuation) and borrows the
  clipboard once as a fallback — saving and restoring what was in it. That
  fallback is *verified*: more than one Copy control can exist in the tree, and
  clicking the wrong one returns a completely different thread's text, which is
  far worse than a short answer because it reads as a genuine reply. The copy is
  accepted only when it overlaps the fragment already read from this thread;
  otherwise it is discarded and the answer is labelled TRUNCATED. If you hit this
  often, ask narrower questions.
- **The sidebar is in the tree too.** It lists the account's other recent
  threads, so a naive read of every static-text line prints unrelated history
  into the transcript. The open question appears twice — once in that sidebar
  list, then again at the top of the thread — so the answer is everything after
  its last occurrence.
- **App state drifts under repeated automated runs.** Driving a native app
  through the accessibility API is not a transaction: a "new session" click can
  fail to take, the app can be left showing an older thread, and the composer can
  re-render and drop text that was just written. Expect an occasional run to
  return NOT-FINISHED (exit 2) or to fail submitting. Retry it; if two runs in a
  row fail, switch to the browser path rather than fighting the app. Every unsafe
  consequence of this drift is guarded — a copied answer is rejected unless it
  matches this thread, and an agent mode blocks the submit — but the flakiness
  itself is inherent, not a bug that can be fully fixed from outside the app.
- **The upstream answer reader may not work** against a current app build; it
  waits on UI details that build no longer exposes. That is why this skill reads
  the accessibility tree itself rather than calling the helper's own reader.
- **Accessibility unlock attributes are unsupported.** The app is native, so the
  attributes that force full accessibility on web-view apps return errors. This
  is expected, not a broken install.

## Modes, models, and money

- **Plain Search** is the default and the right choice for almost everything: a
  question, a claim check, a fast iteration loop.
- **Deep Research** returns far more sources and takes minutes. It draws on a
  daily quota shared with the person's own usage, so ask before running one.
  Judge whether it really ran from the behavior — many steps, minutes, dozens
  of sources. A three-step answer that returns quickly ran as a plain search.
- **Agent modes** (variously called Computer, Control browser, or similar) spend
  paid credits and drive things on their own. This skill never selects them.
- **Tier-gated models and modes** are an upgrade prompt for anyone not on that
  plan. Never select one on the user's behalf.
- If a model selector is changed for one round, set it back afterward — the
  account belongs to a person who will use it next.

## Data boundary

The question, and anything attached to the session as context, leaves the
machine. Keep credentials, keys, private customer records, and material under
an agreement out of it. If folder or file context is useful, create a folder
that holds only shareable material and point the app at that — never at a whole
working repository, which normally contains private files.
