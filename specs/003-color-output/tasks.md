# Tasks: Color Output Pass

All tasks complete. Shipped 2026-03-15.

---

## GetClearKit — shared package

- [x] **T001** — Create `GetClearKit` Swift package in get-clear umbrella repo (`Package.swift`, `Sources/GetClearKit/` target)
- [x] **T002** — `ANSI.swift`: `ANSI.enabled` (isatty + NO_COLOR), `bold()`, `dim()`, `red()`
- [x] **T003** — `Fail.swift`: `fail(_ msg: String) -> Never` — red "Error:" prefix to stderr, exit 1
- [x] **T004** — `Flags.swift`: `isVersionFlag()`, `isHelpFlag()` — all three string variants each

---

## contacts-cli — reference implementation (2026-03-14)

- [x] **T005** — Add GetClearKit dependency to `Package.swift`
- [x] **T006** — Import GetClearKit; remove any inline ANSI or fail logic
- [x] **T007** — Bold contact names in `list`, `find`, `show` output
- [x] **T008** — Dim email/phone labels, secondary fields (company in find)
- [x] **T009** — Red "Error:" prefix via `fail()` on all error paths
- [x] **T010** — Confirm isatty suppression and NO_COLOR suppression work correctly (reference: isatty bug diagnosed here, absent in contacts because GetClearKit was used from the start)

---

## Color pass — remaining four tools (2026-03-15, get-clear #10)

### reminders-cli

- [x] **T011** — Add local `ansiEnabled` (isatty + NO_COLOR) — isatty bug fix
- [x] **T012** — Bold reminder titles in `list` and `find` output
- [x] **T013** — Dim metadata (due date, list name) in list and find
- [x] **T014** — Bold list name in group headers (replaces `---` markers)

### calendar-cli

- [x] **T015** — Add local `ansiEnabled` (isatty + NO_COLOR) — isatty bug fix
- [x] **T016** — Bold event titles and day headers in `list`, `today`, `week` output
- [x] **T017** — Dim location metadata

### mail-cli

- [x] **T018** — Add local `ansiEnabled` (isatty + NO_COLOR)
- [x] **T019** — Bold email subject in `find` results
- [x] **T020** — Dim index numbers, dates, senders in find results

### sms-cli

- [x] **T021** — Add local `ansiEnabled` (isatty + NO_COLOR)
- [x] **T022** — Bold recipient name in send confirmation
- [x] **T023** — Dim phone/email address in send confirmation

---

## GetClearKit migration — all five tools (2026-03-15, get-clear #11, #13)

*Immediately followed the color pass. Replaced per-tool inline helpers with GetClearKit imports.*

### reminders-cli

- [x] **T024** — Add GetClearKit dependency to `Package.swift`
- [x] **T025** — Replace inline `ansiEnabled`, `bold()`, `dim()` with `ANSI.*`
- [x] **T026** — Replace local `fail()` with GetClearKit `fail()`
- [x] **T027** — Replace manual flag string comparisons with `isVersionFlag()` / `isHelpFlag()`

### calendar-cli

- [x] **T028** — Add GetClearKit dependency to `Package.swift`
- [x] **T029** — Replace inline ANSI helpers with `ANSI.*`
- [x] **T030** — Replace local `fail()` with GetClearKit `fail()`
- [x] **T031** — Replace manual flag comparisons with `isVersionFlag()` / `isHelpFlag()`

### mail-cli

- [x] **T032** — Add GetClearKit dependency to `Package.swift`
- [x] **T033** — Replace inline ANSI helpers with `ANSI.*`
- [x] **T034** — Replace local `fail()` with GetClearKit `fail()`
- [x] **T035** — Replace manual flag comparisons with `isVersionFlag()` / `isHelpFlag()`

### sms-cli

- [x] **T036** — Add GetClearKit dependency to `Package.swift`
- [x] **T037** — Replace inline ANSI helpers with `ANSI.*`
- [x] **T038** — Replace local `fail()` with GetClearKit `fail()`
- [x] **T039** — Replace manual flag comparisons with `isVersionFlag()` / `isHelpFlag()`

---

## Closed issues

- [x] **get-clear #10** — color pass, all five tools (isatty bug fixed in reminders + calendar)
- [x] **get-clear #12** — shared `fail()` in GetClearKit (Note: issue numbers shifted during planning; Fail.swift closed what was filed as #11 in some entries and #12 in others — both refer to this work)
- [x] **get-clear #13** — standard flag handling in GetClearKit
