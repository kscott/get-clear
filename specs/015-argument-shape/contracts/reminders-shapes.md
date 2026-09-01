# Contract — Reminders command shapes and their accepted forms

`RemindersLib/ReminderCommandShapes.swift` defines a `CommandShape` for the **eight** argument-taking commands. Every accepted form must parse; every malformed line must throw.

## Shared keyword set

`list`, `priority`, `url`, `repeat` (+ `repeats`/`repeating`/`repeated`), `due` (+ `date`), `by`. `note` is the trailing-text keyword on `add`/`change`.

## The naming rule

Every identifier — a title, a new title, a list name — is **one token**, quoted if it contains a space. No greedy "up to the first keyword." A stray token after the identifier is an error that tells the user to quote. `find`'s query is free text (the rest of the tail), not an identifier — no quotes required.

---

## `add` / `change` — `[req "title"]`, `.bareDate`, keywords `[list, priority, url, repeat, due]`, trailing `note`

Parses:
```
reminders add "Pay rent"
reminders add "Pay rent" march 1
reminders add "Pay rent" due march 1
reminders add "Pay rent" due on march 1
reminders add "Pay rent" on march 1
reminders add "Pay rent" march 1 list Bills repeat monthly priority high
reminders add "Pay rent" list "Household Bills" due "next friday" url https://x.com
reminders add "Call dentist" friday note ask about the crown
reminders add "Call dentist" note "ask about the crown"
reminders add "Pay rent" "march 1" "list" "Bills"          # fully quoted, identical
reminders change "Pay rent" priority high due none          # both apply (FR-012 / SC-004)
```

Rejects:
```
reminders add "Pay rent" Bills march 1          # unexpectedTokens(["Bills","march","1"]) → quote it? add "Bills march 1"
reminders add Pay rent march 1                  # unexpectedTokens(["rent","march","1"]) → quote it? add "Pay rent march 1"
reminders add "Pay rent" march 1 due none       # dateGivenTwice
reminders add "Pay rent" priorty high           # unknownKeyword("priorty")
reminders add "Pay rent" priority               # missingValue(keyword: "priority")
reminders add "Pay rent" list A list B          # duplicateKeyword("list")
reminders add                                   # missingIdentifier(name: "title")
```

## `rename` — `[req "title", req "new title"]`, `.none`, keywords `[list]`

```
reminders rename "Pay rent" "Pay mortgage"
reminders rename "Pay rent" "Pay mortgage" list Bills
```
Rejects:
```
reminders rename "Pay rent"                       # missingIdentifier(name: "new title")
reminders rename "Pay rent" "Pay mortgage" Bills  # unexpectedTokens(["Bills"]) → quote it? rename … list "Bills"
reminders rename Pay rent Pay mortgage            # "rent" consumed as new title, then unexpectedTokens(["mortgage"])
```

## `remove` / `done` / `show` — `[req "title"]`, `.none`, keywords `[list]`

```
reminders remove "Pay rent"
reminders remove "Pay rent" list "Household Bills"
reminders done "Buy milk" list Bills
reminders show "Buy milk"
```
Rejects:
```
reminders remove "Pay rent" Household Bills       # unexpectedTokens(["Household","Bills"]) → quote it? list "Household Bills"
reminders remove Pay rent                         # unexpectedTokens(["rent"]) → quote it? remove "Pay rent"
reminders done                                    # missingIdentifier(name: "title")
```

## `list` — `[opt "list"]`, `.none`, keywords `[by]`

```
reminders list
reminders list "Household Bills"
reminders list "Household Bills" by priority
reminders list by created
```
Rejects / tightens:
```
reminders list Household Bills                    # unexpectedTokens(["Bills"]) → quote it? list "Household Bills"
reminders list "Household Bills" extra            # unexpectedTokens(["extra"])
reminders list by sideways                        # parses; handleList throws "unknown sort: sideways"
                                                  #   (was a silent fallback to due)
```

## `find` — `[]`, `.freeText("query")`, no keywords

```
reminders find dentist
reminders find pick up dry cleaning
reminders find "pick up dry cleaning"            # identical
```
`freeText` is the whole tail. Empty (`reminders find`) → `freeText == nil` → `handleFind` throws `"provide a search query"` (unchanged).

---

## Not given a shape

- **`what`** — `#40` lifts its arg handling into `GetClearKit.runWhatCommand`; `#197` questions tool-level `what`. Untouched by spec 015.
- **`lists` / `open`** — no arguments. `handleLists`/`handleOpen` don't receive the args array today and `.open` dispatches before the switch, so rejecting `reminders open junk` needs extra plumbing — deferred as a small follow-up. Extra tokens are currently ignored (harmless, not a silent wrong action).
