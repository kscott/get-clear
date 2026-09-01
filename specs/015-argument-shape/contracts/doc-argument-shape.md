# Contract — `design.md` section and constitution entry (draft text)

Land in Step 8. `design.md` gets the full section; the constitution gets the condensed mirror. Wording is a draft for review during implementation, not frozen.

**Doc-example convention:** every value that could contain a space is shown quoted — including the trailing text field (`note` / `body` / `message`), even though it does not require quotes. One visible pattern: *quote every value.* The leniency of the trailing field is stated once, in prose, not modeled in the examples.

---

## For `design.md` — new `## Argument shape` section (after "Conversational design")

> ## Argument shape
>
> Every command in the suite has the same shape. Three sentences:
>
> 1. The name comes first, quoted if it contains a space.
> 2. A due date is either bare right after the name or introduced by `due` (or `date`) anywhere — one or the other, never both.
> 3. Everything else is `keyword value`, in any order. `note` / `body` / `message` comes last and takes the rest of the line.
>
> ```
> reminders add "Pay rent" "march 1" list "Bills" repeat monthly priority high
> reminders change "Pay rent" due none priority high
> reminders rename "Pay rent" "Pay mortgage"
> reminders add "Call dentist" friday note "ask about the crown"
> contacts add "Bob Smith" email bob@x.com phone 555-1234
> mail send "Alice Chen" subject "Lunch?" body "Free at noon?"
> ```
>
> **Quoting.** Quote every value that contains a space. Quoting one that doesn't is harmless — a fully-quoted line parses identically — so when in doubt, quote. Use double quotes; if a value contains a literal `"` or `$`, single-quote that one argument.
>
> The one place quotes are optional is the trailing text field (`note` / `body` / `message`): it takes the rest of the line, so `note ask about the crown` and `note "ask about the crown"` are the same. The examples quote it anyway, for consistency.
>
> **`list` is a keyword, not a position.** `reminders add "Pay rent" list "Bills"`, never `reminders add "Pay rent" Bills`. The bare form used to work only when the list already existed and silently became part of the date otherwise — a keyword removes the guesswork and the silent failure.
>
> **Unrecognized input is an error.** A misspelled keyword, a stray word, a keyword with no value, a keyword twice, a date given both ways — each stops the command with a message naming the problem. Nothing is silently absorbed.
>
> The parser is one shared implementation in GetClearKit, driven by a per-command descriptor. See `ARCHITECTURE.md`.

---

## For the constitution — new `## Argument shape` rule

> ## Argument shape
>
> Every command: one identifier first (quoted if it has a space); at most one bare date, or the `due` keyword, not both; every other value introduced by a keyword, order-independent; one optional trailing free-text field (`note` / `body` / `message`) last. Quote every value with a space; quoting any value is safe. The trailing field is the only value where quotes are optional — but examples quote it anyway.
>
> Unrecognized tokens, missing keyword values, duplicate keywords, and a date given two ways are errors — never silently absorbed (see "No silent failures").
>
> The parser is a single shared implementation in GetClearKit (`CommandArguments.swift`), parameterized by a per-command `CommandShape`. Tools declare shapes; they do not write parsers.

---

## Checklist for Step 8 doc sweep (SC-006)

Grep every fenced ` ``` ` block and every inline `reminders …` in:
- `design.md`
- `README.md`
- `PROMPTS.md`
- `reminders-cli/Sources/RemindersLib/UsageText.swift`

For each `reminders add|change|rename|remove|done|show|list|find` example:
- bare positional list → rewrite `list "<name>"`
- any now-rejected form → fix
- **note / body / message content shown unquoted → wrap in quotes** (consistency, per the convention above)
- multi-word `find` query unquoted → quote it

Leave `what` / `lists` / `open` examples alone (not wired in Phase 1).
