# Cross-Tool Code Review — 2026-04-29

## What this is

Full cross-tool review of all five CLI tools in the get-clear monorepo, run after completion of the three-tier migration (#142 mail, #140 calendar). Coverage data is from this same session (`swift test --enable-code-coverage` + `xcrun llvm-cov report`). Suite: 1032 tests, 0 failures. Total line coverage: 80.66%.

## How to use this file

Each finding is numbered and includes `file:line`. Findings are prioritized:
- **Launch blockers** (1–16): architecture violations or missing tests for logic that ships to users
- **Known patterns not yet addressed** (12–16): cross-tool duplication and design violations already in ARCHITECTURE.md backlog
- **New observations** (17–30): quality improvements, force-unwrap risks, coverage gaps

Work one finding at a time on a feature branch. Many of the duplication findings (12–14) are related to issue #40 (GetClearKit shared utilities) and should be addressed there rather than piecemeal.

---

## Findings

### Launch Blockers

**1.** `calendar-cli/Sources/CalendarLib/SetupHandler.swift:79` — [architecture] `signal(SIGINT)` in pure Lib — signal handling is a Unix side effect; belongs in CLI layer, not CalendarLib; makes the function untestable

**2.** `calendar-cli/Sources/CalendarLib/SetupHandler.swift:84,90` — [architecture] `readLine()` calls in pure Lib — interactive I/O in a Lib target violates the layer contract; should be injected as a closure to make the function testable

**3.** `calendar-cli/Sources/CalendarLib/SetupHandler.swift:122-123` — [architecture] `FileManager.createDirectory` and TOML file write in pure Lib — file I/O belongs in CLI or factory layer

**4.** `mail-cli/Sources/MailLib/MailConfiguration.swift:42` — [architecture] `configURL` computed property calls `FileManager` at module level inside MailLib — filesystem access in a pure domain type; belongs in `MailClientFactory` or CLI

**5.** `mail-cli/Sources/MailLib/MailConfiguration.swift:79-84` — [architecture] `loadConfig()` reads from disk in MailLib — I/O in a pure Lib target; should be in `MailClientFactory` or CLI

**6.** `mail-cli/Sources/MailLib/MailConfiguration.swift:86-101` — [architecture] `saveConfig()` calls `FileManager.createDirectory` and writes to disk in MailLib — same violation; should be delegated out of the Lib

**7.** `calendar-cli/Sources/CalendarLib/SetupHandler.swift:10-48` — [coverage] `parseCalendarTokens`, `buildSubsetTOML`, `numberCalendars`, `sanitize` are pure functions with 0% test coverage — ARCHITECTURE.md explicitly calls SetupHandler the reference implementation for testable setup flows; none of its extracted pure functions have specs

**8.** `reminders-cli/Sources/RemindersLib/WhatHandler.swift:7-21` — [coverage] 0% coverage on a function with real logic — `parseRange` call, conditional `ActivityLogReader` path selection, `ActivityLogFormatter` integration; no `WhatHandlerSpec` exists

**9.** `contacts-cli/Sources/ContactsLib/WhatHandler.swift:1-20` — [coverage] 0% coverage, no `WhatHandlerSpec` — handler contains logic including a `parseRange` call and `ActivityLogReader` integration

**10.** `text-cli/Sources/TextLib/WhatHandler.swift:7-23` — [coverage] 0% coverage, no `WhatHandlerSpec` — contains conditional branching: args reconstruction with `"today"` fallback, branch on `rangeStr == "today"` selecting between two `ActivityLogReader` calls

**11.** `contacts-cli/Sources/ContactsLib/WhatHandler.swift:6` — [architecture] calls optional-returning `parseRange(_ input: String)` instead of the throwing `parseRange(trailingArgs:default:)` used by reminders, calendar, and mail — inconsistent signature for the same operation; same applies to `text-cli/Sources/TextLib/WhatHandler.swift`

---

### Already-Known Patterns Not Yet Addressed

**12.** [duplication] All five `WhatHandler` implementations are structurally identical — only the tool name string differs. Extraction to GetClearKit as `runWhatCommand` is already documented as pending #40.
- `reminders-cli/Sources/RemindersLib/WhatHandler.swift:7-21`
- `contacts-cli/Sources/ContactsLib/WhatHandler.swift:4-20`
- `calendar-cli/Sources/CalendarLib/WhatHandler.swift:6-20`
- `text-cli/Sources/TextLib/WhatHandler.swift:7-23`
- `mail-cli/Sources/MailLib/WhatHandler.swift:7-21`

**13.** [duplication] `OpenHandler` pattern is identical across four tools — take an `opener` closure, call it with a tool-specific URL; generic enough to extract to GetClearKit with a URL parameter; no documented reason for the duplication in any file.
- `contacts-cli/Sources/ContactsLib/OpenHandler.swift`
- `reminders-cli/Sources/RemindersLib/OpenHandler.swift`
- `text-cli/Sources/TextLib/OpenHandler.swift`
- `calendar-cli/Sources/CalendarLib/OpenHandler.swift`

**14.** [duplication] `calendarDot()` logic is duplicated between `calendar-cli/Sources/CalendarLib/EventFormatter.swift:51-56` and `reminders-cli/Sources/RemindersLib/CalendarDot.swift:1-7` — ARCHITECTURE.md documents the `hexColor` duplication at the boundary layer but not this one, which is in pure Lib

**15.** `mail-cli/Sources/MailLib/ArgumentParser.swift:42-44` — [design violation] `--draft` flag confirmed present as a Bool extracted from the token list — ARCHITECTURE.md improvement backlog explicitly flags this; should be a `draft` subcommand per the no-flags rule

**16.** [duplication] Both tools implement manual TOML subset parsers with a line-by-line approach:
- `calendar-cli/Sources/CalendarLib/ConfigParser.swift:37-81`
- `mail-cli/Sources/MailLib/MailConfiguration.swift:45-77`
Different schemas but same strategy; worth a shared `TOMLParser` in GetClearKit if a third tool needs config

---

### New Observations

**17.** `calendar-cli/Sources/CalendarEventKit/AppleCalendarStore.swift:76` — [code quality] `Calendar.current.date(byAdding: .hour, value: 1, to: item.startDate)!` — force-unwrap on Calendar arithmetic in the framework boundary; can return nil on edge-case dates; use `??` with a fallback

**18.** `calendar-cli/Sources/CalendarLib/EventDateTime.swift:86` — [code quality] `Calendar.current.date(byAdding: .day, value: 1, to: now)!` — same crash risk in pure Lib code; Calendar arithmetic is not guaranteed non-nil

**19.** `reminders-cli/Sources/RemindersLib/RecurrenceParsing.swift:63,74,85,94` — [code quality] four `try! NSRegularExpression` force-unwraps on static patterns — won't fail with current hardcoded patterns, but any future edit to a pattern will crash at startup rather than fail to compile

**20.** `calendar-cli/Sources/CalendarLib/AddHandler.swift:17` — [code quality] `if calFilter != nil && ... { fail("...\(calFilter!)") }` — force-unwrap immediately after nil check; prefer `if let f = calFilter, ... { fail("...\(f)") }`

**21.** `calendar-cli/Sources/CalendarLib/EventFormatter.swift:99-108` — [coverage] `formatAmbiguous()` is private with 0% coverage but contains real formatting logic for disambiguation messages; should be `internal` and tested

**22.** `reminders-cli/Sources/RemindersLib/ReminderFormatter.swift:107-115` — [code quality] `formatAddConfirmation` has 7 parameters — all independently computed, but a struct would reduce callsite noise

**23.** `calendar-cli/Sources/CalendarLib/ConfigParser.swift:39-40` — [code quality] string literals `"[subsets]"` and `"="` used as section/separator markers without named constants — silent typo risk if the TOML schema is adjusted

**24.** `Sources/ContactKit/ContactStore.swift:28-57` — [coverage] 50% line coverage — `resolve()` and `resolveGroup()` default protocol extension implementations are pure logic with conditional throws, fully testable, not directly exercised in `ContactKitTests`

**25.** `Sources/GetClearKit/TimespanFormatter.swift` — [coverage] 63% lines covered, 3 missed functions — `formatTimespan` variants are pure formatters, untested, straightforward to spec

**26.** `Sources/GetClearKit/ANSI.swift` — [coverage] 45% lines covered — some ANSI formatting helpers untested; worth confirming which are dead code vs live-but-unexercised

**27.** `calendar-cli/Sources/CalendarLib/SetupHandler.swift:10-28` — [coverage] `parseCalendarTokens` specifically — pure function parsing numeric tokens and title strings; 0% covered; straightforward to spec with array inputs (overlaps with finding #7)

**28.** `calendar-cli/Sources/CalendarLib/NextHandler.swift` — [coverage] 72%, 3 missed functions — likely the empty result set and `Int()` parse failure paths; confirm which branches are missing

**29.** `calendar-cli/Sources/CalendarLib/ShowHandler.swift` — [coverage] 76%, 2 missed functions — likely the ambiguous-match callback path and multi-line notes formatting branch

**30.** `calendar-cli/Sources/CalendarLib/AddHandler.swift` — [coverage] 71%, 5 missed functions — calendar filter disambiguation and `ActivityLog.write` error path likely unexercised

---

## Coverage snapshot (Lib targets only, session baseline)

| File | Lines |
|---|---|
| RemindersLib overall | ~97% testable, 91.4% total |
| CalendarLib/SetupHandler.swift | 28.79% |
| CalendarLib/AddHandler.swift | 86.49% |
| CalendarLib/NextHandler.swift | 90.62% |
| CalendarLib/EventFormatter.swift | 92.04% |
| ContactsLib/WhatHandler.swift | 0.00% |
| MailLib/MailConfiguration.swift | 69.44% |
| TextLib/WhatHandler.swift | 0.00% |
| GetClearKit/ANSI.swift | 71.43% |
| GetClearKit/TimespanFormatter.swift | 82.93% |
| ContactKit/ContactStore.swift | 64.29% |

Suite total: 1032 tests, 0 failures, 80.66% line coverage.

---

## Data Clump / Hidden Types (targeted pass)

These are function signatures where multiple base-type parameters always travel together and represent a named type hiding in plain sight. Extracting them reduces callsite noise, enables validation in one place, and makes call sites self-documenting.

**DC-1.** `Sources/GetClearKit/UpdateChecker.swift` — `(version: String, url: String)` tuple returned from `cachedLatest()` and `fetchLatestRelease()`, and passed into `writeCache(version:url:)` — three functions share the same unnamed pair; extract as `struct ReleaseInfo { let version: String; let url: String }` in GetClearKit.

**DC-2.** `calendar-cli/Sources/CalendarLib/SetupHandler.swift:33` — `[(name: String, calendars: [String])]` tuple array passed to `buildSubsetTOML(subsets:)` — named tuple, but a `struct CalendarSubset { let name: String; let calendars: [String] }` is cleaner, documentable, and passable across module boundaries without tuple unpacking.

**DC-3.** `calendar-cli/Sources/CalendarLib/SetupHandler.swift:43` — `[(number: Int, title: String)]` returned from `numberCalendars(_:)` and consumed by `parseCalendarTokens(tokens:numbered:all:)` — the pair has a clear identity; extract as `struct NumberedCalendar { let number: Int; let title: String }`.

**DC-4.** `calendar-cli/Sources/CalendarLib/EventFormatter.swift` — `formatFlat(showHeader: Bool, header: String)` — `Bool` paired with a `String` that is only meaningful when the `Bool` is true is a classic smell; replace with `header: String?` (nil = no header) or `enum HeaderMode { case none; case titled(String) }`.

**DC-5.** `mail-cli/Sources/MailJMAP/JMAPClient.swift:301` — `submitEmail(emailId: String, identityId: String, draftsId: String, sentId: String)` — four raw ID strings with no self-documentation at the call site; extract as `struct MailboxIDs { let drafts: String; let sent: String }` and pair `emailId`/`identityId` separately or in a `PendingSubmission` type.

**DC-6.** `text-cli/Sources/TextLib/SendHandler.swift` — `formatSendConfirmation(name: String, address: String)` — name and address are a resolved contact coordinate that always travel together; `SendResult` already carries both fields but the formatter takes them split; thread `SendResult` through or add a `ResolvedRecipient` value type shared with contacts-cli.

**DC-7.** `reminders-cli/Sources/RemindersLib/ReminderHandlerHelpers.swift` — `storeError(title: String, list: ReminderList?, cmd: String, _ err:)` — title + list + cmd is a lookup context for a reminder operation; extract as `struct ReminderLookupContext { let title: String; let list: ReminderList?; let cmd: String }` if this function grows callers.

**DC-8.** `calendar-cli/Sources/CalendarLib/EventFormatter.swift` — `describeRecurrenceRule(frequency: Int, interval: Int)` — always paired; extract as `struct RecurrenceParams { let frequency: Int; let interval: Int }` if the pair acquires a third field or more callers.

### Priority

DC-1 through DC-4 are the clearest wins — the type name is obvious, the duplication is real, and each would reduce call-site noise immediately. DC-5 and DC-6 are worth doing before #61 (Gmail) since they touch the mail and text send paths that Gmail will exercise. DC-7 and DC-8 are lower priority — single call sites; extract only if they grow.
