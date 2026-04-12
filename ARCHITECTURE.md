# Get Clear — Architecture

This document has three sections: current structure, decision log, and improvement backlog.

**Update this document when:** a structural change is made (new file, new type, extracted function), a significant decision is taken, or something is noticed during work that isn't worth acting on right now. This is the memory across sessions. Keep it current.

---

## Current structure

### Repositories

Currently six separate repos; monorepo migration planned (#34).

- `get-clear/` — umbrella repo: GetClearKit shared library, PKG installer, scripts, specs
- `reminders-cli/` — Apple Reminders CLI
- `calendar-cli/` — Apple Calendar CLI
- `contacts-cli/` — Apple Contacts CLI
- `mail-cli/` — Mail CLI (Fastmail/JMAP; Gmail planned in #14)
- `text-cli/` — Messages CLI (osascript)

### Layer model

Every tool follows the same three-layer model:

```
main.swift          — dispatch only; ~100 lines target; no business logic
*Lib/               — pure Swift; no framework imports; fully unit-testable
GetClearKit/        — shared suite utilities; no tool-specific knowledge
```

The boundary is enforced by the Swift package structure: `*Lib` targets do not import EventKit, Contacts, Security, or AppKit. Framework access lives exclusively in `main.swift`.

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

### Tool Lib targets (as of 2026-04-11)

Each tool has a `*Lib` target. Business logic extraction tracked in #35–39; reminders-cli complete.

| Tool | Lib contains today | CLI helpers (EventKit boundary) | Still needed (tracked) |
|---|---|---|---|
| reminders | `RecurrenceParsing`, `OptionsParsing`, `ReminderFormatter`, `ChangeCommand` | `RecurrenceConversion`, `Sorting` | — (#35 done) |
| calendar | `ConfigParser` | — | `EventDateTime`, `EventFormatter`, `CalendarResolver` (#36) |
| contacts | `ContactRecord`, `matchContacts`, `exportAddresses`, `cleanLabel` | — | `ChangeCommand`, `ContactStore`, `ContactFormatter` (#37) |
| mail | JMAP types, some helpers | — | `MailConfiguration`, `JMAPClient`, `MailFormatter`, `SetupCommand`, `SendCommand` (#38) |
| text | Contact resolution helpers | — | `MessagesClient` (#39) |

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

### Async/await inconsistency across tools

mail-cli uses `async/await` throughout. reminders, calendar, contacts use `DispatchSemaphore`. text uses synchronous Process. The suite has no consistent threading model. mail-cli is right; the others should converge to the same pattern. Not blocking anything today but will matter as complexity grows.

### `versionString` construction duplicated in every tool

`"\(builtVersion) (Get Clear \(suiteVersion))"` appears in all five main.swift files. Belongs in GetClearKit as a shared function taking the two constants. Small, low-risk, easy win during any tool's next touch.

### ~~`TestRunner` duplicated across all five test files~~ — resolved

All six test suites migrated to Quick + Nimble (2026-04-11). Custom TestRunner removed from all repos.

### UpdateChecker tail duplicated in every tool

Two lines at the end of every main.swift:
```swift
UpdateChecker.spawnBackgroundCheckIfNeeded()
if let hint = UpdateChecker.hint() { fputs(hint + "\n", stderr) }
```
Belongs in `runCLI` in GetClearKit. When `runCLI` is the entry point for all tools, this moves once.

### `FieldChange<T>` will be duplicated across reminders and contacts

`FieldChange<T>` (`.unchanged`, `.cleared`, `.set(T)`) is introduced in both `RemindersLib/ChangeCommand.swift` (#35) and `ContactsLib/ChangeCommand.swift` (#37) as the pattern for "was this field specified, and if so, set or clear?" When the monorepo lands (#34), this moves to GetClearKit — one definition, used by all stateful tools. File an issue at that point.
