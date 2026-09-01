# Contract — Reminders command shapes and their accepted forms

`RemindersLib/ReminderCommandShapes.swift` defines a `CommandShape` for the **eight** argument-taking commands. Every accepted form must parse; every malformed line must throw.

## Shared keyword set

`list`, `priority`, `url`, `repeat` (+ `repeats`/`repeating`/`repeated`), `due` (+ `date`), `by`. `note` is the trailing-text keyword on `add`/`change`.

## The one rule

Every identifier — a title, a new title, a list name, a search query — is **one token**, quoted if it contains a space. No greedy "up to the first keyword." A bare unquoted keyword word (`list`, `by`, `priority`, …) is never consumed as an identifier — `reminders add list` errors; quote it (`reminders add "list"`) to force it. A stray token after the identifier is an error that tells the user to quote — except on `add` / `change`, whose `.bareDate` leading region takes the stray phrase as the date string, so the error surfaces from date parsing instead. The trailing text field (`note`) is the only value where quotes are *optional* — but every example below quotes it anyway, so there is one visible pattern: quote every value with a space.

---

## `add` / `change` — `[req "title"]`, `.bareDate`, keywords `[list, priority, url, repeat, due]`, trailing `note`

Parses:
```
reminders add "Pay rent"
reminders add "Pay rent" march 1
reminders add "Pay rent" due march 1
reminders add "Pay rent" due on march 1                     # "on friday" → date parser strips "on"; same as "march 1"
reminders add "Pay rent" on march 1                         # same
reminders add "Pay rent" "march 1" list "Bills" repeat monthly priority high
reminders add "Pay rent" list "Household Bills" due "next friday" url https://x.com
reminders add "Call dentist" friday note "ask about the crown"
reminders add "Call dentist" note ask about the crown       # also parses — note quotes are optional; docs quote anyway
reminders change "Pay rent" priority high due none          # both apply (FR-012 / SC-004)
```

Rejects (`add` / `change` use `.bareDate`, so an unquoted phrase in the leading region becomes the date string and fails **date** parsing — a clear error, not a silent drop; it does not produce `unexpectedTokens`):
```
reminders add "Pay rent" Bills march 1          # bareDate = "Bills march 1" → date parse fails → "couldn't parse date: Bills march 1"
reminders add Pay rent march 1                  # title = "Pay", bareDate = "rent march 1" → date parse fails
reminders add "Pay rent" march 1 due none       # dateGivenTwice
reminders add "Pay rent" priorty high           # unknownKeyword("priorty")
reminders add "Pay rent" priority               # missingValue(keyword: "priority")
reminders add "Pay rent" priority urgent        # parses; handler rejects "urgent" — "unknown priority: urgent" (FR-024)
reminders add "Pay rent" list A list B          # duplicateKeyword("list")
reminders add list                              # missingIdentifier(name: "title") — "list" is a keyword; quote it: add "list"
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
reminders rename "Buy milk" list                  # missingIdentifier(name: "new title") — "list" is a keyword; quote it
reminders rename "Pay rent" "Pay mortgage" Bills  # unexpectedTokens(["Bills"]) — quote as part of a name, or use list "Bills"
reminders rename Pay rent Pay mortgage            # title = "Pay", new title = "rent", then unexpectedTokens(["Pay","mortgage"])
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
reminders remove "Pay rent" Household Bills       # unexpectedTokens(["Household","Bills"]) — meant list "Household Bills"
reminders remove Pay rent                         # title = "Pay", then unexpectedTokens(["rent"]) — quote it: remove "Pay rent"
reminders remove list                             # missingIdentifier(name: "title") — "list" is a keyword; quote it
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
reminders list Household Bills                    # filter = "Household", then unexpectedTokens(["Bills"]) — quote it: list "Household Bills"
reminders list "Household Bills" extra            # unexpectedTokens(["extra"])
reminders list by sideways                        # parses; handleList errors "unknown sort: sideways" (FR-024; was a silent fallback to due)
```

## `find` — `[req "query"]`, `.none`, no keywords

```
reminders find dentist
reminders find "pick up dry cleaning"
```
Rejects:
```
reminders find pick up dry cleaning              # query = "pick", then unexpectedTokens(["up","dry","cleaning"]) — quote it: find "pick up dry cleaning"
reminders find                                   # missingIdentifier(name: "query")
```

---

## Not given a shape

- **`what`** — `#40` lifts its arg handling into `GetClearKit.runWhatCommand`; `#197` questions tool-level `what`. Untouched by spec 015.
- **`lists` / `open`** — no arguments. `handleLists`/`handleOpen` don't receive the args array today and `.open` dispatches before the switch, so rejecting `reminders open junk` needs extra plumbing — deferred as a small follow-up. Extra tokens are currently ignored (harmless, not a silent wrong action).
