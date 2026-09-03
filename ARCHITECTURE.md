# Get Clear — Architecture

**Update this document when:** a structural decision is made or a significant pattern is established. GitHub issues are the source of truth for work to be done — nothing task-like belongs here.

---

## Current structure

### Layer model

Every tool has three package targets. The split is structural, not conventional — the Swift package graph enforces it. A Lib target that doesn't declare a framework dependency cannot accidentally import one.

**`*Lib`** — all domain logic. Pure Swift, no system framework imports. Handler functions take protocol types, return `String`, and throw domain errors. Value types, parsing, formatting, lookup decisions, and validation all live here. The rule: if it's a decision — which record to update, how to interpret input, whether a field is valid, what the output should say — it belongs in Lib.

The canonical handler signature: `func handle*(args: ParsedArgs, store: any *Store) throws -> String`. No framework types in the parameter list. No side effects beyond what the store protocol permits. Return value is the output string printed by the CLI.

**Framework boundary** (`*EventKit`, `*Messages`, `*JMAP`, etc.) — imports the system framework and implements the Lib protocol. Its job is type conversion and field assignment. A line of code at the boundary should read like `field = value`, not like a decision. A conditional at the boundary is a signal that logic has leaked from Lib. Pure assignment needs no tests — the field names say what they do.

**Auditing for boundary leakage:** `grep -rn "private func" <boundary-dirs>` surfaces every candidate. The filter: if the function's signature contains no framework types (`EK*`, `CN*`, `JMAP*`, etc.), it has no reason to be at the boundary — it's a pure function that belongs in Lib where it can be tested. Functions whose signatures are entirely `String → String` or `String → Bool` are the clearest offenders.

**`*CLI` / `main.swift`** — requests permissions, constructs the concrete store, dispatches to handler functions, prints output. 30–40 lines. No logic beyond dispatch.

**`GetClearKit`** — shared infrastructure with no tool-specific knowledge. Check here before writing anything suite-wide — if it's not tool-specific, it probably belongs here or already exists. What's in it: `Command` enum + `runCLI` (version/help/unknown dispatch), `parseArgs`/`ParsedArgs` (argument parsing), `parseRange`/`ParsedRange` (date and range parsing), `ValueChange<T>` (suite-wide change type), `ANSI` (colour output), `ActivityLog` (logging sent items), `UpdateChecker` (version check on launch).

**`AppleEventKitSupport`** — shared CoreGraphics utilities used by boundary targets that import EventKit. Cannot live in GetClearKit because GetClearKit is pure Foundation and cannot import CoreGraphics. Does not import EventKit itself — only CoreGraphics. The rule for adding here: the function must be framework-adjacent (operating on CoreGraphics or similar types) but contain no EventKit or business logic. Currently: `rgbComponents(from: CGColor?)` and `hexColor(from: CGColor?)`.

### The backend substitution test

A new backend (Gmail, Google Calendar) must be implementable by creating a new boundary target — without changing any handler, formatter, Lib function, or shared type.

If adding a backend requires changing handler signatures, error types, result types, or resolution logic, the shared protocols are not right yet. The test: could you swap `AppleReminderStore` for a hypothetical `GoogleTasksStore` and have every handler in RemindersLib work unchanged? If not, find what's wrong with the abstraction and fix it before the second backend lands.

This is the principle behind the pre-#61 foundation issues. `HandlerContext` (#174), `SendAddress` (#167), and `HandlerError` (#168) are not cleanup — they are the condition under which Gmail is a new implementation of an existing protocol rather than a new set of patterns. The same applies to `NamedCollection` (#171) before Google Calendar (#55): `GoogleCalendarStore` should return `[NamedCollection]` for the same reason `AppleCalendarStore` does.

A backend that is hard to add is a signal that something in Lib owns a decision it should not own, or that a shared type has not been named yet.

### Making code testable

Everything in `*Lib` should be tested — not just handlers, but parsers, formatters, value types, lookup functions, and any logic with a branch. If it lives in Lib and isn't covered, that's a gap to close, not a known limitation to accept.

Handler functions take a protocol (`any *Store`), not a concrete framework type. Tests inject a spy. No permissions, no framework state — just domain types in, strings out.

The active discipline is to pull code toward Lib, not to accept what ended up in CLI. If logic is sitting in `main.swift` or at the boundary because it was convenient to write there, the question is what refactor moves it into Lib where it can be tested.

When code seems untestable, find the design that makes it testable:

- **Extract pure functions.** Parsing, validation, formatting, and lookup are pure functions. They don't need a store or a framework — pull them out and spec them directly.
- **Identify missing value types.** A function that's hard to test is often doing too many things. Name what it's computing, give it a clear initializer, and the caller becomes a thin coordinator over testable pieces.
- **Watch for data clumps** (Fowler). When the same group of parameters appears together across multiple functions, they're usually a domain concept that hasn't been named yet. The tell: if you removed one item from the group, the others would stop making sense together. The pattern may span more than one method — that's often how you spot it. Extract a struct, name the concept, and it becomes explicit, documentable, and constructable in tests.
- **Inject I/O as closures.** Interactive flows that call `readLine()` or write files should take those operations as closure parameters — the function stays pure and testable, the CLI or factory layer provides the real implementation.
- **Separate the decision from the side effect.** If logic and I/O are entangled, pull the decision out first (what to write, what message to show), then let something else act on it. The decision is testable; the act doesn't need to be.

The threshold: if exercising a branch requires a permission dialog or a file to exist on disk, the code is in the wrong layer.

**Suite type naming.** Suite types are plain, unprefixed `<Thing>Tests` (e.g. `AddHandlerTests`), scoped to their test module. Identically-named suites in different targets (`RemindersLibTests.AddHandlerTests`, `ContactsLibTests.AddHandlerTests`) do not collide — they are module-scoped Swift types, not ObjC-runtime-registered classes. Filenames stay `*Spec.swift`, one per source file.

---

## Decision log

### 2026-09-02 — Shared command-argument parser (spec 015)

**Decision:** One argument parser for the whole suite — `parseCommand(_:shape:)` in `Sources/GetClearKit/CommandArguments.swift` — driven by a per-command `CommandShape` descriptor (`identifiers`, `leading` region, `keywords`, `trailingTextKeyword`). It replaces reminders' join-everything-then-regex-split `parseOptions`, which silently dropped a bare multi-word list name and treated `due` as filler instead of a keyword. Every identifier is exactly one token, quoted if it has a space — no "greedy up to the first keyword" — with a keyword's value following the same one-token rule, except `due`/`date`, which stays free-form multi-token since it's the same field as the bare date, just introduced explicitly (FR-013). `list` is now a required keyword on every reminders command that names a target list, not a bare positional. Phase 1 wires all eight of reminders' argument-taking commands (`add`, `change`, `rename`, `remove`, `done`, `show`, `list`, `find`); Phase 2 (#192 calendar, #193 contacts, #194 mail, #195 text) wires the rest.

**Why:** The old parser had two live "no silent failures" holes: a bare multi-word list name that didn't match an existing calendar silently became part of the date string, and `change "X" priority high due none` dropped the `due none` clear because `due` was stripped as filler ahead of whatever keyword happened to come first. FR-024 also closed three more: an unrecognized `priority` value, an unknown `list … by` sort key, and an unparseable date on `add`/`change` all used to drop or default silently; they now error, matching how recurrence already behaved.

**A key implementation nuance:** a keyword's value is capped at one token (not greedy) specifically so `ArgumentError.unknownKeyword` is reachable at all — under a fully generic "collect until the next recognized keyword" reading, a stray unrecognized token would always get silently absorbed into whatever value or bareDateRange region preceded it, and the case would be unreachable code. `due`/`date` is the sole exception because it's semantically the same field as the bare date/range, which is itself free-form.

**2026-09-02, same day — renamed `bareDate` to `bareDateRange`.** Discovered while starting #192 (calendar): the field was never date-specific in behavior, only in its first consumer (reminders). Calendar needs the identical mechanism for a bare range (`calendar find dentist next week`). Renamed `LeadingRegion.bareDate` → `.bareDateRange` and `ParsedCommand.bareDate` → `bareDateRange` before a second tool could build on the misleading name — purely an internal Swift symbol, never user-visible (confirmed: no error message or usage text references it).

**Deferred:** `lists` / `open` take no arguments and don't currently receive the args array (`.open` dispatches before the command switch), so a stray-token guard for them needs plumbing outside this feature's scope — **#201**.

### 2026-09-01 — Test framework: Swift Testing (spec 016)

**Decision:** The suite moved from Quick + Nimble to Swift Testing. `describe`/`context` → nested `@Suite` structs; `it` → `@Test`; Nimble matchers → `#expect` / `#require`. Filenames stay `*Spec.swift`, one per source file. 1,073 `it` blocks → 1,073 `@Test`, zero consolidations.

**Why:** Quick's `QuickSpec` subclasses `XCTestCase`, so every test transitively linked XCTest — which ships only with a full Xcode install, not the Command Line Tools. A CLT update in mid-2026 stopped bundling XCTest and `swift test` broke on every machine without Xcode; CI (Xcode-equipped runners) kept passing and masked it.

**This is the second round trip.** Before 2026-04-11 (`99a20f6`) the tests were a hand-rolled `TestRunner` harness that existed specifically to avoid the XCTest/Xcode dependency. Adopting Quick + Nimble traded it back. Swift Testing — toolchain-bundled, no XCTest — solves it properly: the suite now builds and runs on CLT-only and on Linux.

**Toolchain:** `swift-tools-version` 5.9 → 6.0 (Swift Testing's SwiftPM integration needs it); language mode stays v5 via package-level `swiftLanguageModes: [.v5]`. The five vestigial `*-cli/Package.swift` (+ `.resolved`, + dead `.github/` workflows) were deleted at the same time. One production line changed: `ReminderChangeError` gained `Equatable` to match its three sibling error types.

**CLT tooling:** SwiftPM 6.x on the Command Line Tools does not wire up the bundled `Testing.framework` (passes `-I` where it needs `-F`; the test binary's rpath misses `Testing.framework` and `lib_TestingInterop.dylib`). `scripts/test` adds the `-F` / `-rpath` flags; devs and hooks call it instead of bare `swift test`. CI (full Xcode) is unaffected and `ci.yml` stays `swift test`.

### 2026-04-10 — Command enum and runCLI added to GetClearKit

**Decision:** All command name strings are defined once in `GetClearKit/Commands.swift` as a `Command` enum. Each tool declares a private `Cmd` subset enum whose `init?` maps suite commands to tool-local cases. `runCLI` owns version/help/empty/unknown dispatch.

**Why:** Five tools each maintained their own string literals for command names. Any rename or addition required changes in multiple places with no compile-time safety. The `sms`→`text` rename was missed in the installer HTML for exactly this reason.

**What it revealed:** The `knownCommands` set in calendar-cli duplicated flag detection that belongs in GetClearKit. Fixed in the same session (commit 591d269).

### 2026-04-10 — Monorepo migration decided

**Decision:** Migrate all six repos into `get-clear` as a monorepo before public launch.

**Why:** GetClearKit changes require push + `swift package update` in each tool repo. Cross-cutting refactors span six repos. Issue history is split. The Command enum refactor made the friction tangible — every GetClearKit change is a two-repo operation.

**Plan:** git filter-repo for history import; gh issue transfer for open issues; API recreation with backlinks for closed issues; archive tool repos. Full plan in #34.

### 2026-04-27 — ValueChange<T> adopted as suite-wide change type (#141)

**Decision:** `ValueChange<T>` (cases: `.unchanged`, `.cleared`, `.added(T)`, `.removed(T)`, `.replaced(from: T, to: T)`) lives in `GetClearKit` and is the standard change type for all tool change structs. Parser and handler code enforce cardinality at the boundary — single-value fields only ever produce `.cleared` or `.replaced`; the type permits more than any field uses.

**Why:** Contacts introduced the need to distinguish multi-value fields (email, phone) from single-value fields (company) in the same change struct. Two types with no shared structure drift independently as cases are added. One type with parser-enforced cardinality eliminates that risk. Suite-wide adoption prevents the cross-tool surprise of different tools using different patterns.

**Boundary enforcement for single-value fields:** the handler fetches the current value before constructing `.replaced(from: currentValue, to: newValue)`. The user supplies `from:` for multi-value fields directly in the command. `.added` and `.removed` are unreachable from single-value handler code — not guarded by runtime checks, just never constructed.

**Retrofit:** reminders-cli (#147) predates this decision and uses a local `FieldChange<T>` in `ReminderChangeParsing.swift`. A follow-up issue tracks the retrofit to `ValueChange<T>`.

### 2026-04-25 — text-cli three-tier migration complete (#143)

**Decision:** Three tiers introduced — `TextLib` (pure handlers + protocols), `TextMessages` (boundary: `AppleMessageSender`), `TextCLI` (dispatch only). `MessageSender` protocol with `SendResult` return type makes handlers testable with a spy. All contact resolution logic lives in `TextLib/TargetResolver.swift` — not at the boundary — so any future backend can call `resolveTarget` and `requiresContactLookup` without duplicating logic. `AppleMessageSender` is three lines: check if lookup needed, resolve, send.

**Why:** `text` is the lightest migration — two commands, one mutating. The `MessageSender` protocol enables testing `handleSend` without Messages.app or osascript. Contact resolution via `matchContacts` (ContactKit) and `normalizePhone` (TextLib) replaces the old `resolveSendTarget`/`MessageContact` pair, which is now deleted. `makeContactStore()` from ContactStoreFactory owns permission; `StoreFactory` in TextCLI injects it into `AppleMessageSender`.

**Key patterns:**
- `resolveTarget(query:contacts:) -> SendResult` in TextLib — handles phone detection, email detection, name matching, ambiguous throw; returns `SendResult` directly
- `requiresContactLookup(_:) -> Bool` in TextLib — defers contact fetch (and permission prompt) until actually needed
- `handleSend(args:sender:)` receives `any MessageSender`; returns `String`; no contacts parameter
- `handleOpen(opener:)` follows reminders pattern — takes a `(URL) -> Void` closure, no contacts needed
- async `@Test` functions are `func …() async throws` — Swift Testing has no async/sync suite split
- `TextMessages` depends on `ContactKit` (not Contacts framework directly); `text-bin` depends on `ContactStoreFactory`

### 2026-04-25 — Shared contact resolution library added (#150)

**Decision:** Four targets implement the shared contact layer:
- `ContactKit` — pure: `Contact`, `ContactField`, `ContactStore`, `matchContacts`. No framework imports. All Lib targets depend on this.
- `AppleContactKit` — Apple boundary: `AppleContactStore`, `toContact()`, `cleanLabel()`. Links Contacts framework.
- `ContactStoreFactory` — shared factory: `makeContactStore()`. Depends on all backends. All CLI binaries depend on this.
- (future) `GoogleContactKit` — Google boundary, same pattern as `AppleContactKit`.

**Why:** Three tools (contacts, mail, text) each maintained their own contact type and name-matching logic. The shared library is a pre-requisite for #141–143. The three-target split (types / boundary / factory) satisfies FR-004: adding a new backend requires only a new boundary target and an update to `ContactStoreFactory` — zero changes to any tool.

**Why not GetClearKit:** GetClearKit is suite infrastructure (ANSI, arg parsing, commands, update checker). Contact types are domain-specific; placing them in GetClearKit would make it a monolith and obscure the clean layer boundary.

**Scope note:** `MessageContact` deleted in #143 (text-cli), `ContactRecord` deleted in #141 (contacts-cli) — both migrations complete. `MailContact` (mail-cli) remains pending — migration deferred to #142.

**Key patterns:**
- `ContactField: Equatable, Hashable, Sendable` — named type instead of tuple so `Contact` can conform to `Equatable`
- `matchContacts` is a free function, not a protocol requirement — pure, testable, no store dependency
- `toContact()` and `cleanLabel()` are `internal` in `AppleContactKit` — not part of the tool-implementor contract
- `makeContactStore()` in `ContactStoreFactory` is the single entry point for all CLI binaries; concrete backend type never exposed

### 2026-04-29 — mail-cli three-tier migration complete (#142)

**Decision:** Three tiers introduced for mail — `MailLib` (pure handlers + protocol), `MailJMAP` (JMAP boundary), `MailCLI` (dispatch only). Plus `MailClientFactory` — a fourth target mirroring `ContactStoreFactory` for backend selection.

**Key patterns:**
- `MailClient` protocol with `send(_:)`, `saveDraft(_:)`, `find(query:limit:)`, `fetchIdentities()`. Two separate methods for send vs. draft avoids a Bool flag on `OutboundEmail`.
- `OutboundEmail` pure value type with `from: MailIdentity`, `to/cc: [AddressEntry]`, resolved body text, attachment paths. `[AddressEntry]` is the resolved type; `[String]` is the unresolved query type passed to `buildRecipients`.
- `buildRecipients(to: [String], cc: [String], ...)` — symmetric `[String]` for both fields, ready for multi-recipient when the parser supports it.
- `MailClientFactory` wraps backend construction so `main.swift` and all handlers are backend-agnostic. Gmail support (#61) adds a new `GmailClient: MailClient` + backend selection in `MailClientFactory` without touching any handler.
- `Keychain.swift` moved to `MailJMAP` — JMAP credential storage is backend-specific, not suite infrastructure.
- `selectIdentityEmail(from:choice:)` extracted to `MailLib/SetupHandler.swift` — the testable pure function from the interactive setup flow.
- `RecipientResolver` updated to use `Contact` (ContactKit) and `matchContacts()` — `MailContact` deleted.
- `webAppURL` added to `MailConfig` (defaults to Fastmail) — mail has no native app to open, so the URL is config-driven.

**Gmail blockers remaining for #61:** `MailConfig` needs a `backend` field, `MailClientFactory` needs backend dispatch, `makeMailClient(token:)` API is JMAP-specific (Gmail OAuth is browser-based), `SetupCommand` is entirely JMAP-specific.

### 2026-04-29 — calendar-cli three-tier migration complete (#140)

**Decision:** Three tiers introduced for calendar — `CalendarLib` (pure handlers + protocols), `CalendarEventKit` (framework boundary), `CalendarCLI` (dispatch only). Follows reminders-cli as template.

**Key patterns:**
- `CalendarStore` protocol with `resolve` default extension for not-found/ambiguous lookup; `CalendarStoreError` mirrors `ReminderStoreError`.
- `EventItem`, `CalendarItem`, `AttendeeItem` pure value types — no EventKit imports in CalendarLib.
- `SetupHandler` designed for testability: three public pure functions (`numberCalendars`, `parseCalendarTokens`, `buildSubsetTOML`) extracted from the interactive `handleSetup` entry point. Serves as reference implementation for mail-cli's setup flow.
- `handleDefault` returns `String?` (nil when args don't parse as a range) — kept in CalendarLib for testability. `main.swift` `default:` case calls `usage()` directly; bare-range shorthands like `calendar monday` are not supported (use `calendar list monday`).
- `.open` and `.what` dispatched before store construction, matching contacts-cli pattern.
- `parseRange(trailingArgs:default:) throws -> ParsedRange` added to GetClearKit to eliminate the two-line `dropFirst`+`guard` pattern duplicated across WhatHandlers; RemindersLib `WhatHandler` retrofitted.
- Suite type naming: suite types are unprefixed `<Thing>Tests`, module-scoped. `CalendarLibTests.RemoveHandlerTests` and `ContactsLibTests.RemoveHandlerTests` coexist — Swift Testing suites are Swift types, not ObjC-runtime classes, so there is no collision. (Was: `Calendar`-prefixed classes under Quick.)

**hexColor duplication (resolved):** `hexColor` was duplicated between `RemindersEventKit` and `CalendarEventKit` and initially accepted as necessary because CGColor requires CoreGraphics, which can't go in GetClearKit. Later resolved by creating `AppleEventKitSupport` — a shared target that imports CoreGraphics but not EventKit. See 2026-05-06 decision log entry.

**Test coverage:** CalendarLibTests ships with 14 handler spec files + 4 shared/infrastructure specs (CalendarStoreSpec, CalendarResolverSpec, EventFormatterSpec, CalendarWhatHandlerSpec). 1,073 total suite tests (`swift test`, spec 016), 0 failures; ~81.6% aggregate line coverage.

### 2026-04-24 — Three-tier model introduced; reminders-cli complete (#147)

**Decision:** Framework boundary code gets its own package target (`*EventKit`) between the Lib and CLI. The boundary target imports system frameworks and owns type conversion, but contains no business logic — pure field assignment only.

**Why:** With only two tiers, the "conversion layer" in `main.swift` accumulated logic that belonged in the Lib but couldn't be tested. The third tier makes the separation structural and enforceable: anything that's a decision goes in Lib, anything that's `field = value` stays at the boundary.

**Key patterns:**
- Domain types encapsulate lookup decisions: `ReminderList.matches(identifier:title:)` — the boundary passes values, makes no decision.
- Parsing at Lib boundary: `FieldChange<URL>` not `FieldChange<String>` — URL parsing happens in `RemindersLib`, not `RemindersEventKit`.
- Handler functions return `String`, throw `ReminderHandlerError` — fully testable via `SpyStore`.
- `ReminderStore` protocol with `resolve` default extension for not-found/ambiguous lookup.

**Test coverage:** RemindersLib is at ~92.6% line coverage (`xcrun llvm-cov`, spec 016) including structural zeros (`WhatHandler`, `OpenHandler`, `UsageText`). Testable code coverage is ~98%. `hexColor` moved from RemindersLib to RemindersEventKit (framework type conversion belongs at the boundary) — CalendarDot.swift is now 100% covered and has no framework imports.

**Template:** reminders-cli is the reference implementation. #140–143 follow this pattern for the other four tools.


### 2026-05-06 — AppleEventKitSupport added for shared CoreGraphics utilities (#164)

**Decision:** New target `AppleEventKitSupport` owns utilities that operate on CoreGraphics types and are needed by multiple EventKit boundary targets. It imports CoreGraphics only — not EventKit, not Foundation. Both `RemindersEventKit` and `CalendarEventKit` depend on it; `GetClear` (which uses CGColor for ANSI terminal output) also depends on it.

**Why:** `hexColor(from: CGColor?)` was duplicated verbatim in `RemindersEventKit` and `CalendarEventKit` with no tests. The duplication was initially accepted because CoreGraphics can't go in the pure-Foundation GetClearKit. The real solution was a fourth shared target with a narrower constraint. The same session revealed that `calendarDot` in `RecapFormatter` and `mimeType(for:)` in `JMAPClient` were also private pure functions at the wrong layer — both moved to their respective Lib targets.

**The pattern this established:** A `private func` in a boundary file whose signature contains no framework types has no reason to be there. It's a pure function that belongs in Lib (or a shared support target) where it can be tested. See "Auditing for boundary leakage" in the layer model section.

### 2026-04-10 — Business logic extraction made a pre-launch blocker

**Decision:** All business logic must be extracted from `main.swift` into Lib targets before public release. This is a quality gate, not a post-launch cleanup.

**Why:** Five main.swift files averaging 500+ lines contain untested logic — date parsing, field updates, protocol details, formatting. The audit (2026-04-10) found 15 categories of structural problems. Shipping with this structure means shipping with untestable code and no path to improving it without a full rewrite.

**Issues:** #35 (reminders), #36 (calendar), #37 (contacts), #38 (mail), #39 (text). Test coverage tracked in #41–45.

### 2026-04-10 — Engineering disciplines encoded in design.md

**Decision:** Code quality expectations for this project — including expectations of Claude — are recorded in `design.md` under "Engineering disciplines — inviolable." These are not guidelines; they are the standard.

**Why:** Code quality issues went unraised across multiple sessions. The `main.swift` bloat, duplication of the `what` command, and string-literal command names were all visible but never flagged. The disciplines section makes the expectation explicit and durable.

