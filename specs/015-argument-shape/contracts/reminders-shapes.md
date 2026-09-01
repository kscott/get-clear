# Contract — Reminders command shapes and their accepted forms

`RemindersLib/ReminderCommandShapes.swift` defines one `CommandShape` per mutating command. Every form below must parse; every malformed line must throw.

## Shared keyword set

`list`, `priority`, `url`, `repeat` (+ `repeats` / `repeating` / `repeated`), `due` (+ `date`). `note` is the trailing-text keyword on `add` / `change`.

## `add` — identifiers `["title"]`, bare date, keywords `[list, priority, url, repeat, due]`, trailing `note`

Parses:
```
reminders add "Pay rent"
reminders add "Pay rent" march 1
reminders add "Pay rent" due march 1
reminders add "Pay rent" due on march 1
reminders add "Pay rent" on march 1
reminders add "Pay rent" march 1 list Bills repeat monthly priority high
reminders add "Pay rent" list "House Stuff" due "next friday" url https://x.com
reminders add "Call dentist" friday note ask about the crown
reminders add "Call dentist" note "ask about the crown"
reminders add "Pay rent" "march 1" "list" "Bills"          # fully quoted, identical result
```

Rejects:
```
reminders add "Pay rent" Bills march 1          # unexpectedTokens(["Bills","march","1"])  → hint: list "Bills march 1"
reminders add "Pay rent" march 1 due none       # dateGivenTwice
reminders add "Pay rent" priorty high           # unknownKeyword("priorty")
reminders add "Pay rent" priority               # missingValue(keyword: "priority")
reminders add "Pay rent" list A list B          # duplicateKeyword("list")
reminders add                                   # missingIdentifier(name: "title")
```

## `change` — identifiers `["title"]`, bare date, keywords `[list, priority, url, repeat, due]`, trailing `note`

Parses:
```
reminders change "Pay rent" friday
reminders change "Pay rent" due none
reminders change "Pay rent" priority high due none          # both apply (FR-012 / SC-004)
reminders change "Pay rent" list "House Stuff" priority high
reminders change "Pay rent" repeat none note updated context
```

Rejects: same classes as `add`, plus `change "Pay rent" march 1 due none` → `dateGivenTwice`.

## `rename` — identifiers `["title", "new title"]`, no bare date, keywords `[list]`

Parses:
```
reminders rename "Pay rent" "Pay mortgage"
reminders rename "Pay rent" "Pay mortgage" list Bills
```

Rejects:
```
reminders rename "Pay rent"                     # missingIdentifier(name: "new title")
reminders rename "Pay rent" "Pay mortgage" Bills  # unexpectedTokens(["Bills"]) → hint: list "Bills"
```

## `remove` / `done` / `show` — identifiers `["title"]`, no bare date, keywords `[list]`

Parses:
```
reminders remove "Pay rent"
reminders remove "Pay rent" list "House Stuff"
reminders done "Pay rent" list Bills
reminders show "Pay rent"
```

Rejects:
```
reminders remove "Pay rent" House Stuff         # unexpectedTokens(["House","Stuff"]) → hint: list "House Stuff"
reminders done                                  # missingIdentifier(name: "title")
```

## Not wired in Phase 1

`reminders list [name] [by order]`, `reminders find <query>`, `reminders what [range]`, `reminders lists`, `reminders open` — current parsing retained (research.md R4).
