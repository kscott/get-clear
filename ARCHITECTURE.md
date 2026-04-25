# Get Clear — Architecture

This document has three sections: current structure, decision log, and improvement backlog.

**Update this document when:** a structural change is made (new file, new type, extracted function), a significant decision is taken, or something is noticed during work that isn't worth acting on right now. This is the memory across sessions. Keep it current.

---

## Current structure

### Repositories

Single monorepo at `~/dev/get-clear/` (#34 complete 2026-04-16). All standalone repos archived. Tool source lives under `<tool>-cli/Sources/` subdirectories within the monorepo.

- `Sources/GetClearKit/` — shared suite infrastructure: ANSI, Fail, Flags, DateParser, RangeParser, Commands, ArgParsing, ActivityLog, UpdateChecker, ToolIdentity
- `Sources/ContactKit/` — pure shared contact types: Contact, ContactField, ContactStore protocol, matchContacts()
- `Sources/AppleContactKit/` — Apple Contacts boundary: AppleContactStore, toContact(), cleanLabel()
- `Sources/ContactStoreFactory/` — shared backend factory: makeContactStore(); update here when adding new backends
- `Sources/GetClear/` — umbrella `get-clear` binary (what, recap, check-update)
- `reminders-cli/Sources/` — RemindersLib + RemindersCLI
- `calendar-cli/Sources/` — CalendarLib + CalendarCLI
- `contacts-cli/Sources/` — ContactsLib + ContactsCLI
- `mail-cli/Sources/` — MailLib + MailCLI (JMAP/Fastmail; Gmail #61)
- `text-cli/Sources/` — TextLib + TextMessages + TextCLI (osascript → Messages.app)
- `Tests/GetClearKitTests/` — Quick/Nimble specs; per-tool coverage open in #41–45
- `Tests/ContactKitTests/` — cleanLabel and SpyContactStore specs

### Layer model

Every tool follows the same three-tier model:

```
*CLI/main.swift     — dispatch only; ~40 lines; no business logic
*EventKit/ (etc.)   — framework boundary; pure assignment; owns type conversion
*Lib/               — pure Swift; no framework imports; all domain logic; fully unit-testable
GetClearKit/        — shared suite utilities; no tool-specific knowledge
```

The boundary is enforced by the Swift package structure: `*Lib` targets do not import EventKit, Contacts, Security, or AppKit. Framework access lives exclusively in the framework boundary target.

**What belongs where:**
- `*Lib`: all domain logic — parsing, validation, lookup decisions, handler functions, formatting. Everything testable.
- Framework boundary: pure assignment of domain values to framework fields. No conditionals beyond what the framework API forces (e.g. `addRecurrenceRule` requires non-nil). No business logic.
- `*CLI/main.swift`: request permissions, construct the store, dispatch to handlers, print output, catch errors.

**The pure boundary rule:** if it's a decision (which API to call, whether to set a field, how to look something up), it belongs in Lib. If it's "field = value," it stays at the boundary. Pure assignment is acceptable without tests — the field names say what they do. Conditionals at the boundary are a signal that logic has leaked.

### GetClearKit (as of 2026-04-10)

| File | Job |
|---|---|
| `ArgParsing.swift` | `parseArgs` → `ParsedArgs` enum; intercepts --help/-h from any position |
| `Commands.swift` | `Command` enum (suite-wide command names); `runCLI` dispatch function |
| `Flags.swift` | `isHelpFlag`, `isVersionFlag` |
| `ANSI.swift` | Bold/dim/red output; isatty + NO_COLOR detection |
| `Fail.swift` | `fail()` — red-prefixed error to stderr, exit non-zero |
| `DateParser.swift` | `ParsedDate`, `parseDate()`, `formatDate()` |
| `RangeParser.swift` | `ParsedRange`, `parseRange()`, `formatRangeDescription()` |
| `ActivityLog.swift` | Write timestamped entries to `~/.local/share/get-clear/log/` |
| `ActivityLogReader.swift` | Read and filter activity log entries |
| `ActivityLogFormatter.swift` | Format activity log output for `what` and `recap` commands |
| `ActivityLogEntry.swift` | `ActivityLogEntry` value type |
| `TimespanFormatter.swift` | Human-readable timespan formatting |
| `UpdateChecker.swift` | Background version check; hint on stderr at most once per hour |

### Tool Lib targets (as of 2026-04-24)

All five extractions complete (#35–39). Each tool's `main.swift` is ≤60 lines — dispatch only.

**reminders-cli** — three-tier complete (#147):
- `RemindersLib`: nine handler functions, `ReminderStore` protocol + `resolve` extension, `ReminderChangeParsing`, `OptionsParsing`, `RecurrenceParsing`, `ReminderFilter`, `ReminderFormatter`, `ReminderGrouping`, `ReminderItem`, `ReminderList`, `ReminderLookup`, `ReminderSorting`, `ReminderHandlerError`, `ReminderHandlerHelpers`, `CalendarDot`
- `RemindersEventKit` (framework boundary): `AppleReminderStore` (single file; absorbs type conversion, recurrence conversion, change application)
- `RemindersCLI`: `main.swift`, `StoreFactory`, `Usage`, `Version`

**text-cli** — three-tier complete (#143):
- `TextLib`: `SendHandler`, `OpenHandler`, `WhatHandler`, `MessagesClient`, `PhoneNormalizer`, `TextErrors`, `MessageSender` (protocol + `SendResult`), `TargetResolver` (`resolveTarget`, `requiresContactLookup`), `UsageText`
- `TextMessages` (boundary): `AppleMessageSender` — delegates resolution to `TargetResolver`, osascript dispatch
- `TextCLI`: `main.swift`, `StoreFactory`, `Usage`, `Version`

**Other tools** — two-tier (Lib + CLI); three-tier pending (#140–142):
| Tool | Lib contains |
|---|---|
| calendar | `CalendarResolver`, `ConfigParser`, `EventDateTime`, `EventFormatter`, `ChangeCommand` |
| contacts | `ArgumentParser`, `ChangeCommand`, `ContactFormatter`, `Matching` |
| mail | `JMAPClient`, `MailConfiguration`, `MailErrors`, `MailFormatter`, `RecipientResolver`, `SendCommand`, `SetupCommand` |

Protocol abstraction layer (CalendarStore, ContactStore, MailClient) tracked in #140–142. Use reminders-cli as the template. Required before Google backends (#145, #146).

### Command dispatch (as of 2026-04-10)

`GetClearKit/Commands.swift` defines the `Command` enum (single source of truth for all command names) and `runCLI` (handles version/help/empty/unknown dispatch).

Each tool defines a private `Cmd` enum whose `init?(_ c: Command)` declares the tool's supported subset. The switch in the handler is exhaustive over `Cmd` — compiler enforces completeness.

contacts-cli is the reference implementation (adopted 2026-04-10, commit 37e9a75). Remaining tools tracked in #33.

---

## Decision log

### 2026-04-10 — Command enum and runCLI added to GetClearKit

**Decision:** All command name strings are defined once in `GetClearKit/Commands.swift` as a `Command` enum. Each tool declares a private `Cmd` subset enum whose `init?` maps suite commands to tool-local cases. `runCLI` owns version/help/empty/unknown dispatch.

**Why:** Five tools each maintained their own string literals for command names. Any rename or addition required changes in multiple places with no compile-time safety. The `sms`→`text` rename was missed in the installer HTML for exactly this reason.

**What it revealed:** The `knownCommands` set in calendar-cli duplicated flag detection that belongs in GetClearKit. Fixed in the same session (commit 591d269).

### 2026-04-10 — Monorepo migration decided

**Decision:** Migrate all six repos into `get-clear` as a monorepo before public launch.

**Why:** GetClearKit changes require push + `swift package update` in each tool repo. Cross-cutting refactors span six repos. Issue history is split. The Command enum refactor made the friction tangible — every GetClearKit change is a two-repo operation.

**Plan:** git filter-repo for history import; gh issue transfer for open issues; API recreation with backlinks for closed issues; archive tool repos. Full plan in #34.

### 2026-04-25 — text-cli three-tier migration complete (#143)

**Decision:** Three tiers introduced — `TextLib` (pure handlers + protocols), `TextMessages` (boundary: `AppleMessageSender`), `TextCLI` (dispatch only). `MessageSender` protocol with `SendResult` return type makes handlers testable with a spy. All contact resolution logic lives in `TextLib/TargetResolver.swift` — not at the boundary — so any future backend can call `resolveTarget` and `requiresContactLookup` without duplicating logic. `AppleMessageSender` is three lines: check if lookup needed, resolve, send.

**Why:** `text` is the lightest migration — two commands, one mutating. The `MessageSender` protocol enables testing `handleSend` without Messages.app or osascript. Contact resolution via `matchContacts` (ContactKit) and `normalizePhone` (TextLib) replaces the old `resolveSendTarget`/`MessageContact` pair, which is now deleted. `makeContactStore()` from ContactStoreFactory owns permission; `StoreFactory` in TextCLI injects it into `AppleMessageSender`.

**Key patterns:**
- `resolveTarget(query:contacts:) -> SendResult` in TextLib — handles phone detection, email detection, name matching, ambiguous throw; returns `SendResult` directly
- `requiresContactLookup(_:) -> Bool` in TextLib — defers contact fetch (and permission prompt) until actually needed
- `handleSend(args:sender:)` receives `any MessageSender`; returns `String`; no contacts parameter
- `handleOpen(opener:)` follows reminders pattern — takes a `(URL) -> Void` closure, no contacts needed
- `SendHandlerSpec` uses `AsyncSpec` (not `QuickSpec`) — required for async `it` closures in Quick/Nimble
- `TextMessages` depends on `ContactKit` (not Contacts framework directly); `text-bin` depends on `ContactStoreFactory`

### 2026-04-25 — Shared contact resolution library added (#150)

**Decision:** Four targets implement the shared contact layer:
- `ContactKit` — pure: `Contact`, `ContactField`, `ContactStore`, `matchContacts`. No framework imports. All Lib targets depend on this.
- `AppleContactKit` — Apple boundary: `AppleContactStore`, `toContact()`, `cleanLabel()`. Links Contacts framework.
- `ContactStoreFactory` — shared factory: `makeContactStore()`. Depends on all backends. All CLI binaries depend on this.
- (future) `GoogleContactKit` — Google boundary, same pattern as `AppleContactKit`.

**Why:** Three tools (contacts, mail, text) each maintained their own contact type and name-matching logic. The shared library is a pre-requisite for #141–143. The three-target split (types / boundary / factory) satisfies FR-004: adding a new backend requires only a new boundary target and an update to `ContactStoreFactory` — zero changes to any tool.

**Why not GetClearKit:** GetClearKit is suite infrastructure (ANSI, arg parsing, commands, update checker). Contact types are domain-specific; placing them in GetClearKit would make it a monolith and obscure the clean layer boundary.

**Scope note:** `MessageContact` deleted in #143 (text-cli migration complete). `ContactRecord` (contacts-cli) and `MailContact` (mail-cli) remain pending — migration deferred to #141–142.

**Key patterns:**
- `ContactField: Equatable, Hashable, Sendable` — named type instead of tuple so `Contact` can conform to `Equatable`
- `matchContacts` is a free function, not a protocol requirement — pure, testable, no store dependency
- `toContact()` and `cleanLabel()` are `internal` in `AppleContactKit` — not part of the tool-implementor contract
- `makeContactStore()` in `ContactStoreFactory` is the single entry point for all CLI binaries; concrete backend type never exposed

### 2026-04-24 — Three-tier model introduced; reminders-cli complete (#147)

**Decision:** Framework boundary code gets its own package target (`*EventKit`) between the Lib and CLI. The boundary target imports system frameworks and owns type conversion, but contains no business logic — pure field assignment only.

**Why:** With only two tiers, the "conversion layer" in `main.swift` accumulated logic that belonged in the Lib but couldn't be tested. The third tier makes the separation structural and enforceable: anything that's a decision goes in Lib, anything that's `field = value` stays at the boundary.

**Key patterns:**
- Domain types encapsulate lookup decisions: `ReminderList.matches(identifier:title:)` — the boundary passes values, makes no decision.
- Parsing at Lib boundary: `FieldChange<URL>` not `FieldChange<String>` — URL parsing happens in `RemindersLib`, not `RemindersEventKit`.
- Handler functions return `String`, throw `ReminderHandlerError` — fully testable via `SpyStore`.
- `ReminderStore` protocol with `resolve` default extension for not-found/ambiguous lookup.

**Test coverage:** RemindersLib reached 91.4% line coverage including structural zeros (`WhatHandler`, `OpenHandler`, `UsageText`). Testable code coverage is ~97.8%. `hexColor` moved from RemindersLib to RemindersEventKit (framework type conversion belongs at the boundary) — CalendarDot.swift is now 100% covered and has no framework imports.

**Template:** reminders-cli is the reference implementation. #140–143 follow this pattern for the other four tools.


### 2026-04-10 — Business logic extraction made a pre-launch blocker

**Decision:** All business logic must be extracted from `main.swift` into Lib targets before public release. This is a quality gate, not a post-launch cleanup.

**Why:** Five main.swift files averaging 500+ lines contain untested logic — date parsing, field updates, protocol details, formatting. The audit (2026-04-10) found 15 categories of structural problems. Shipping with this structure means shipping with untestable code and no path to improving it without a full rewrite.

**Issues:** #35 (reminders), #36 (calendar), #37 (contacts), #38 (mail), #39 (text). Test coverage tracked in #41–45.

### 2026-04-10 — Engineering disciplines encoded in design.md

**Decision:** Code quality expectations for this project — including expectations of Claude — are recorded in `design.md` under "Engineering disciplines — inviolable." These are not guidelines; they are the standard.

**Why:** Code quality issues went unraised across multiple sessions. The `main.swift` bloat, duplication of the `what` command, and string-literal command names were all visible but never flagged. The disciplines section makes the expectation explicit and durable.

---

## Improvement backlog

Items noticed during work that aren't worth stopping for now but must not be forgotten. Add an item here rather than letting it evaporate. Remove items when they become GitHub issues or are resolved.

### CoreData 134092 retry loop (contacts-cli/main.swift:347–386)

Complex stderr suppression and multi-source retry logic for saving contacts across containers. Deliberately deferred from #37 — warrants its own dedicated review. Risk: this pattern is unique in the suite and fragile. Should eventually move to `ContactsLib/ContactStore.swift` with a clean interface.

### `--draft` flag in mail-cli

`design.md` already flags this: "The `--draft` flag in mail is the current exception to audit next." Flags are wrong per the design principles. Needs a proper command name or removal.

### ~~Async/await inconsistency across tools~~ — resolved

All five tools migrated to async/await in #139 (2026-04-22). DispatchSemaphore removed. UpdateChecker ownership moved into `runCLI` in the same migration.

### ~~`TestRunner` duplicated across all five test files~~ — resolved

All six test suites migrated to Quick + Nimble (2026-04-11). Custom TestRunner removed from all repos.

### ~~UpdateChecker tail duplicated in every tool~~ — resolved

Moved into `runCLI` in GetClearKit as part of #139 (2026-04-22).

### Test suite is regression coverage — close the gap via SpecKit

The existing Quick/Nimble specs were written after (or alongside) extractions from `main.swift`. Tests written this way never fail on first run — they're designed to pass. They catch regressions but didn't drive design: interfaces were frozen before tests were written.

The extraction work in #35–39, #139, and #144 couldn't avoid this; the interface was inherited. But new features have no such excuse.

**SpecKit creates the right conditions for genuine TDD:** the plan step defines interface contracts (inputs, outputs) before any implementation code exists. The correct workflow for new features is: plan defines the interface → write failing specs against that interface → `/speckit.implement` makes them pass. A spec that's never been red is not a spec — it's a description of code that already exists.

### ContactKit cleanup — #153

Four items filed during #143 review: (1) wrong module name in `ContactStoreSpec` header (says GetClearKit, should say ContactKit); (2) `SpyContactStoreSpec` uses pre-async-migration `waitUntil` + `Task` pattern — should use `AsyncSpec`; (3) `ContactStore.swift` has two jobs (protocol + `matchContacts`) — split into separate files; (4) `AppleContactStore.contacts()` blocks the cooperative thread pool — should use `withCheckedThrowingContinuation` + `DispatchQueue`.

### `FieldChange<T>` will be duplicated across reminders and contacts

`FieldChange<T>` (`.unchanged`, `.cleared`, `.set(T)`) is introduced in both `RemindersLib/ReminderChangeParsing.swift` (#147) and `ContactsLib/ChangeCommand.swift` (#37) as the pattern for "was this field specified, and if so, set or clear?" This moves to GetClearKit as part of #40 — one definition, used by all stateful tools.
