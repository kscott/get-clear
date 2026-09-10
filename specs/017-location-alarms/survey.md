# Pre-Plan Survey: Reminder Location Alarms

**Feature**: [spec.md](./spec.md) · **Branch**: `017-location-alarms` · **Date**: 2026-09-09

Two parallel surveys of the monorepo — one for the existing capability landscape, one for seams and risk. This document is what `/speckit.plan` should not have to rediscover.

---

## Headline: this is not a small feature

Issue #191 called it "own SpecKit spec (small)." It isn't. As specified, it requires changes to **three pieces of shared infrastructure** before any reminder-specific code is written:

1. **The shared argument parser** (`Sources/GetClearKit/CommandArguments.swift`) — filler words have no mechanism today. Used by all six binaries.
2. **The shared contact layer** (`Sources/ContactKit/`, `Sources/AppleContactKit/`) — `Contact` has no addresses and `ContactStore` has no me-card accessor. Used by three tools.
3. **Config file read/write** (`Sources/GetClear/GetClearConfig.swift`) — lives in an executable target no Lib can import, and its only writer overwrites the whole file.

Plus a new resolver target triple for geocoding, plus the reminders-tool work itself. Sequencing is a real decision, not a formality. See **Scope forks** at the end.

---

## 1. What exists in this problem space

**Nothing.** `grep` for `EKAlarm|EKStructuredLocation|CLLocation|CoreLocation|CLGeocoder|MKLocalSearch|MapKit|proximity` across all Swift sources returns zero hits outside `specs/017-location-alarms/`.

- `AppleReminderStore.add` (`reminders-cli/Sources/RemindersEventKit/AppleReminderStore.swift:57-71`) sets title, calendar, dueDateComponents, recurrence, priority, notes, url. No alarms.
- `ReminderItem.init(_ r: EKReminder)` (`:120-134`) reads the same seven fields and ignores `r.alarms` entirely.
- `reminders-bin` links only EventKit and AppKit (`Package.swift:118-124`). CoreLocation/MapKit is a new linked framework, and it links **from the binary**, not from a library target.

Calendar has an `EventItem.location` (`calendar-cli/Sources/CalendarLib/EventItem.swift:15`) but it is read-only — rendered at `EventFormatter.swift:64`, with no `location` keyword in `CalendarCommandShapes`. It is a display string, not a geofence, and shares nothing with this feature.

## 2. The attribute pipeline a location alarm must join

| Stage | File:line |
|---|---|
| Shape declaration | `RemindersLib/ReminderCommandShapes.swift:10-34` |
| Shared parse | `GetClearKit/CommandArguments.swift:159` |
| ParsedCommand → DTO | `RemindersLib/OptionsParsing.swift:8-28` |
| Value type | `RemindersLib/ReminderItem.swift:6-46` |
| Change type | `RemindersLib/ReminderChangeParsing.swift:9-21` |
| parse → describe | `ReminderChangeParsing.swift:49-74` + one `changedX` per field at `:76, :103, :121, :131, :144` |
| apply | `RemindersEventKit/AppleReminderStore.swift:191-220` (`applyChanges`), `:57-71` (`add`) |
| EK → domain | `AppleReminderStore.swift:120-134` |
| show render | `RemindersLib/ReminderFormatter.swift:83-102` |
| add confirmation | `ReminderFormatter.swift:108-139` |
| usage text | `RemindersLib/UsageText.swift:9-12, 35-44` |

`ValueChange<T>` (`Sources/GetClearKit/ValueChange.swift`) is the right carrier: `.cleared` for FR-009, `.replaced(from:to:)` for FR-008. `LocationAlarm` needs to be `Equatable`, as `ReminderItem` already is.

**The existing wart this lands beside:** `add` and `change` do not share a validation path. `AddHandler.swift:20-40` re-parses date, recurrence, and priority itself with its own error strings; `ChangeHandler` delegates to `parseReminderChanges`. A location alarm would be the sixth field validated twice — and the first whose validation is *expensive and fallible in a new way* (a network round trip returning 0, 1, or many answers). Duplicating that means either two geocoding call sites or an awkward asymmetry.

Related live defect noticed in passing: both paths silently drop an unparseable URL (`AddHandler.swift:48`, `ReminderChangeParsing.swift:149` — `URL(string:)` returning nil is discarded). That is a "no silent failures" violation in the exact function the new field sits next to.

## 3. The keyword problem

**Conjugations are free.** `Keyword(_:aliases:repeatable:)` (`CommandArguments.swift:32-47`), resolved at `:312-323`, alias words folded into the keyword set at `:295-307`. `repeat` already ships `aliases: ["repeats", "repeating", "repeated"]` (`ReminderCommandShapes.swift:17`). FR-002 needs no parser change.

**But `resolveKeyword` discards which alias matched** — it returns `canonical` (`:318-319`) and `ParsedCommand.values` is keyed by canonical (`:86-88`). That forces a fork:

- **Two separate `Keyword`s** (`arriving`, `leaving`): direction is recoverable, but FR-006 (both directions in one command must fail) is *not* a duplicate — the parser sees two distinct canonicals and accepts both. The conflict check must be hand-written.
- **`leaving` as an alias of `arriving`**: FR-006 falls out of `duplicateKeyword` (`:259-261`) for free, and FR-009's "either direction's `none` clears it" becomes trivially true — but canonicalization destroys the direction, so `ParsedCommand` must record the matched alias.

The second is the cleaner model (the direction is a property of one alarm, which is exactly what FR-007 says) but needs a small parser extension: an alias that acts as a *discriminant* rather than a synonym. The parser has no such concept today.

**Filler words (FR-003) are a genuine GetClearKit extension, and a trap.** There is no filler mechanism anywhere. The only filler handling in the suite is `parseDate`'s `"on "` prefix strip (`GetClearKit/DateParser.swift:47-50`), which works only because `due` is the one keyword with a free-form multi-token value (`CommandArguments.swift:264-268, 293`). A location keyword's value is single-token (`:269-272`), so today:

- `arriving at "Whole Foods"` → `valueTokens = ["at"]`, then `"Whole Foods"` throws `unknownKeyword` (`:249-251`). **The place becomes the error message.**
- `when arriving at "Whole Foods"` → `when` isn't a keyword word, so it is swallowed as `bareDateRange` (`:210-225`) and `AddHandler.swift:21-24` fails with **`couldn't parse date: when`** — an error about a date the user never mentioned.

And the obvious fix is wrong: **a global filler strip breaks live vocabulary.** `reminders add "X" friday at 5pm` currently joins to `bareDateRange = "friday at 5pm"` and `parseDate` handles the `at` (`DateParser.swift:94`). `from` is live in contacts (`contacts remove Bob from "Team Members"`, `design.md:204-209`). Any filler mechanism must be **scoped per-keyword** — e.g. `Keyword(_:fillers:)` consumed only adjacent to that keyword — never a global ignore-list.

This is the most under-specified piece of the feature, and it lands in code all six binaries share. `Tests/GetClearKitTests/CommandArgumentsSpec.swift` (300 lines) grows with it.

## 4. The contact layer is greenfield for this

- `Contact` (`Sources/ContactKit/Contact.swift:22-44`) has `emails`, `phones`, `company`. **No addresses.**
- `AppleContactStore.keysToFetch` (`Sources/AppleContactKit/AppleContactStore.swift:9-16`) does not request `CNContactPostalAddressesKey`.
- **No me-card concept anywhere** — zero hits for `unifiedMeContact|meContact|postalAddress|CNPostalAddress`.
- `ContactStore` (`Sources/ContactKit/ContactStore.swift:25-34`) has eight methods, none of them "the person's own card."

What *is* already right: `cleanLabel` (`Sources/ContactKit/ContactLabel.swift:3-9`) strips Apple's `_$!<Home>!$_` wrapping and lowercases — exactly the normalization FR-012's case-insensitive Home/Work/School matching needs. The label mechanism is done; the field is missing.

**Decision the plan must make once:** `ContactField` is `label: String, value: String`. A `CNPostalAddress` is structured (street/city/state/postal/country), and FR-015 requires naming the resolved address back to the user. Flattening to one string is low-friction; a real `PostalAddress` type is honest, gives `contacts show` something to render (`ContactFormatter.swift:4-18` has an obvious slot), and is a standalone improvement. Retrofitting later is a cross-tool change, so decide now.

Mitigation: `Contact.init` (`:33-44`) and `makeContact` (`Tests/ContactTestSupport/Fixtures.swift:44-51`) are both explicit and take a defaulted new parameter without churning existing fixtures.

## 5. Package graph edits are required

`RemindersLib` declares exactly one dependency — `GetClearKit` (`Package.swift:104-108`). `reminders-bin` takes `RemindersEventKit` + `GetClearKit` only (`:113-124`). Three requirements each force an edit:

- FR-012/FR-014 → `RemindersLib` needs `ContactKit`; `reminders-bin` needs `ContactStoreFactory`. Precedent: `TextLib` (`:222-226`), `MailLib` (`:186-190`), and their binaries.
- Geocoding → CoreLocation cannot go in pure `RemindersLib` and should not go in the tool-specific `RemindersEventKit`. The architecture-fitting shape is the `ContactKit`/`AppleContactKit`/`ContactStoreFactory` triple documented at `ARCHITECTURE.md:178-197`: a pure target with `Place`/`ResolvedPlace` and a `PlaceResolver` protocol, an Apple boundary target, and a factory the binary wires in.
- FR-023 → see §7.

## 6. The backend substitution test — a real problem, not a formality

`ARCHITECTURE.md:27-35` requires that a hypothetical `GoogleTasksStore` satisfy every RemindersLib handler unchanged. **Location alarms are the first reminder attribute a plausible second backend cannot implement** — Google Tasks has no geofence.

`ReminderStoreError` (`ReminderStore.swift:6-9`) has two cases, `.notFound` and `.ambiguous`. There is no `.unsupported` and no capability query on the protocol (`:11-20`). A `GoogleTasksStore` handed a populated location change can only drop it silently (violates the constitution) or throw something outside the enum.

Note the asymmetry with the existing near-miss: `recurrenceSpec` is also backend-flavoured, but every plausible task backend has recurrence, so it never surfaced. This one does. `ARCHITECTURE.md:35` treats "a backend that is hard to add" as a signal, so **silence here will read as an oversight in review.** The plan should either add a capability signal to `ReminderStore` or record explicitly why the hole is accepted.

Second-order and important: the resolver is **not** part of `ReminderStore`. `AppleReminderStore` never sees a place name, only a resolved coordinate. That split is what keeps the substitution test mostly intact — the tempting shortcut of resolving inside the store breaks it completely.

## 7. Config (FR-022/FR-023) is the worst structural surprise

- `GetClearConfig` / `loadGetClearConfig()` live in `Sources/GetClear/GetClearConfig.swift:4-27` — **an executable target** (`Package.swift:26-31`). `RemindersLib` cannot import it.
- The parser (`:29-58`) is a hand-rolled `[recap]`-only reader understanding exactly one key, and it **silently drops everything else**.
- There is no writer. `GetClearKit/SetupKit.swift:56-58` does a whole-file atomic overwrite, and `SetupCommand.swift:73-78` rebuilds the file from a string literal.

So FR-023 is not "read a flag." It requires read-modify-write on a file whose parser cannot round-trip unknown keys — naively writing the notice flag **erases the user's `[recap]` calendars**. It also requires moving config into `GetClearKit` (or a new shared target) and wiring it into `reminders-bin`.

Two smaller notes: the telemetry-consent field the constitution describes (`constitution.md:87-91`) **doesn't exist in the struct yet either**, so 017 would be the first second key, full stop. And the notice must never fire from `show` — `constitution.md:43-45`, read-only commands never write.

Nearest precedent for persisted cross-invocation state: `GetClearKit/UpdateChecker.swift:24-28`, a JSON cache under `~/.local/share/get-clear/`. That's a cache, which the constitution treats differently from config.

## 8. Handler shape, async, and the third collaborator

`handleAdd(args:store:)` (`AddHandler.swift:6`) and `handleChange(args:store:)` (`ChangeHandler.swift:5`) take exactly two parameters. Place resolution needs a **second collaborator**. Adding a third parameter is the obvious move — but `ARCHITECTURE.md:33` and `going-live.md:112` reserve `HandlerContext` (**#174**) for precisely this pressure, and it **does not exist yet** (zero occurrences in any `.swift`). Doing the ad-hoc thing quietly makes #174 harder. Decide deliberately.

**Async is a non-issue.** Both handlers are already `async throws`; every `ReminderStore` and `ContactStore` method is `async throws`; `main.swift:20-30` already awaits every dispatch. Swift Testing has no async/sync split (`ARCHITECTURE.md:175`).

**One caveat:** `parseReminderChanges` (`ReminderChangeParsing.swift:49`) is deliberately synchronous and pure so it can be tested without EventKit. Making it `async` to resolve inside it would ripple into ~20 call sites in `ChangeCommandSpec.swift`. **Resolve in the handler, pass the resolved value in** — which FR-018 (abort before any write) demands anyway.

**The pure-resolution template already exists:** `TextLib/TargetResolver.swift:9` — `resolveTarget(query:contacts:) throws -> SendResult` takes already-fetched data and returns or throws, with `requiresContactLookup(_:)` (`:44`) deferring the fetch so the permission prompt only fires when needed. The direct analogue: a pure `resolvePlace(...)` fed already-fetched data, plus an `isPersonalPlace(_:) -> Bool` gate so the contact fetch is skipped for "Whole Foods" — which FR-013 requires anyway.

## 9. `none`, and a requirement with no precedent

`"none"` is compared literally in five places in `ReminderChangeParsing.swift` (`:80, :107, :128` via `parsePriority:37`, `:133, :146`), plus twice in contacts. The location alarm is the sixth copy — `review.md:67-71` makes that worth an explicit sentence either way.

**FR-010 (clearing when there is no alarm reports "nothing to change") has no precedent.** `changedNote` (`:133-135`) returns `.cleared` unconditionally whether or not a note existed. The nearest thing is `ReminderChangeError.nothingToChange` (`:25`), raised only when *no field at all* was named (`:66-68`). Its message string at `ChangeHandler.swift:25-26` — "nothing to change — specify a date, repeat, priority, note, url, or list" — also needs the new keywords added.

## 10. Ambiguity: this would be the fifth implementation

Four independent spellings of 0/1/many exist today, with no shared type:

| Tool | Carrier | Message builder |
|---|---|---|
| reminders | `ReminderStoreError.ambiguous([ReminderItem])` (`ReminderStore.swift:6-9, :22-33`) | `disambiguationMessage` (`ReminderFormatter.swift:147-153`) |
| calendar | `CalendarStoreError.ambiguous([EventItem])` (`CalendarStore.swift:7, :28`) | `formatAmbiguous` (`EventFormatter.swift:91-100`) |
| contacts | `ContactStoreError.ambiguous([Contact])` (`ContactStore.swift:9, :46`) | inline in `LocalizedError` (`:18`) |
| text | `TextError.ambiguous(String)` — pre-formatted (`TargetResolver.swift:24-30`) | — |

Plus a fifth, index-based: `LookupResult` (`RemindersLib/ReminderLookup.swift:4-8`).

`disambiguationMessage` is hard-coded to `[ReminderItem]` and **cannot** be reused for place candidates (FR-016). Place resolution is the fifth domain, and the first where candidates aren't records the user already owns. **#40 already names "multi-match" as a GetClearKit consolidation target** — a `Resolution<T>` introduced here would pay down a debt the repo has already booked.

## 11. Tests that change

In `reminders-cli/Tests/RemindersLibTests/`:

| File | Why |
|---|---|
| `ReminderCommandShapesSpec.swift` (287) | New keywords. **The parameterized self-validation suite at `:243-286` will fail if `arriving`/`leaving` share any alias** (`canonicalsAreUnique`, `:258-269`) and forbids colliding with `note` (`:280-285`). |
| `ChangeCommandSpec.swift` (460) | New `changedLocation` branches, `none`, FR-010. |
| `OptionsParsingSpec.swift` (100) | New fields on `parseOptions`. |
| `ReminderFormatterSpec.swift` (381) | FR-021 `formatShow`, FR-015 confirmation. |
| `ShowHandlerSpec.swift` (60), `AddHandlerSpec.swift` (141), `ChangeHandlerSpec.swift` (172) | **A new handler parameter changes every call site in these three files**, including tests that don't care about locations. |
| `UsageTextSpec.swift` (44) | Substring assertions won't break, but `review.md:13` wants new ones. |
| `Tests/GetClearKitTests/CommandArgumentsSpec.swift` (300) | Only if filler words land — which FR-003 requires. |
| `Tests/ContactTestSupport/` | If `Contact` gains addresses. |

**`SpyStore` can express a location alarm with no changes at all.** It records `addedItems: [ReminderItem]` (`Fixtures.swift:13, :31-34`) and `updatedItems: [(id, ReminderChanges)]` (`:17, :36-38`); a field on `ReminderItem` and a `ValueChange` on `ReminderChanges` are directly assertable. `makeItem` (`:66-88`) is a defaulted factory, so a new parameter breaks zero call sites, and `ReminderChanges` is never constructed in tests.

**What `SpyStore` cannot express is the resolver** — a second collaborator needs its own spy or injected closure. Design that before writing code; it's also the coverage answer.

## 12. Coverage and lint

`review.md:10` requires a coverage review before closing; `ARCHITECTURE.md:243` records RemindersLib at ~92.6% line / ~98% of testable code. The structurally uncoverable new code is the network geocode itself. Two established answers, both applicable: **closure injection** (`ARCHITECTURE.md:50`; live precedent `handleOpen(args:opener:)` wired at `main.swift:13`) and **protocol + factory** (`ContactStoreFactory/StoreFactory.swift:10-19`; reminders' own copy at `RemindersCLI/StoreFactory.swift:8-17` is the natural construction site).

Either way, the decisions — personal-vs-general routing, 0/1/many, which label to match — must sit in a pure Lib function fed already-fetched data, or they will be uncoverable.

**SwiftLint** (`.swiftlint.yml`; `Tests/` excluded at `:9-15`): `cyclomatic_complexity` warn 15 (`:82-84`), `function_body_length` warn 60 (`:71-73`), `function_parameter_count` warn 5 (default).

- **`handleAdd` is the real risk** — `AddHandler.swift:6-59` is already ~52 lines with ~11-12 branches. Adding location parsing, resolution, and the FR-022 notice crosses both thresholds. **Extract, don't append.** Precedent: `ARCHITECTURE.md:69`.
- **`applyChanges` is the second** — `AppleReminderStore.swift:191-220` is four switches plus an `if case`, ≈13-14. A fifth switch plausibly crosses 15. Splitting is also layer-correct, since setting a location alarm means clearing the existing proximity alarm first (`EKReminder.alarms` is an array) — the same clear-then-set shape recurrence already uses at `:199-203`.
- **Don't give `ReminderChanges` an explicit init.** It has none (`:9-21`), so the memberwise init is synthesized and `function_parameter_count` doesn't apply. An explicit 7-param `public init` trips the warning immediately.

## 13. Smaller things that will bite

- **`formatShow` uses no ANSI at all** (`ReminderFormatter.swift:83-102` — plain `"Due:      …"`). FR-024 wants the place dim as metadata, and `constitution.md:97-101` mandates it, but contacts' equivalent dims its labels (`ContactFormatter.swift:8-16`) while reminders' doesn't. Adding the first `ANSI.dim` here makes the block internally inconsistent. Follow the local convention and say so, or fix the whole function — not half.
- **`UsageText.swift:9-12`** already wraps the `add`/`change` synopses over two lines each; two keywords plus six conjugations plus three fillers won't fit that layout. `:35-41` and `:43-44` both need entries.
- **Leave `list`/`find` alone.** The spec puts them out of scope, so `metaLine`/`ReminderMeta` (`ReminderFormatter.swift:9-50`) stay untouched. The "add a `hasLocation` flag next to `hasNote`/`hasURL`" instinct is strong and would be wrong.
- **Shell completions are safe** — `completions/_reminders` enumerates command names only, not keywords.
- **The `reminders` Claude skill lives outside the repo** (`~/.claude/skills/reminders`). It documents the vocabulary for the Claude-driven mode `design.md:9-17` treats as co-equal, so it will silently go stale. Same category as spec 015's unfinished T038.

---

## Scope forks for `/speckit.plan`

Each of these changes the size of the feature, and the first two change what "done" means.

1. **Filler words (FR-003).** Requires a per-keyword filler mechanism in the shared parser. Either extend `CommandShape`/`Keyword` here, land it as its own issue first, or cut FR-003 and require `arriving "Whole Foods"` exactly.
2. **The remembered notice (FR-022/023).** Requires moving config into `GetClearKit` and building a read-modify-write TOML writer that round-trips unknown keys. That is arguably its own feature — and the constitution already anticipates a `get-clear settings` command.
3. **Contact addresses.** Cross-tool change to `ContactKit`. Flattened string or structured `PostalAddress` — decide once.
4. **`Resolution<T>`.** Introduce the shared 0/1/many type here (paying down #40) or write the fifth bespoke one.
5. **`HandlerContext` (#174).** Pull it forward, or add an ad-hoc third parameter and accept that #174 gets harder.
6. **Backend capability signal.** Add `.unsupported` to `ReminderStore`, or record why the hole is accepted.

**Recommended reading order for the planner:** §3 (keyword fork) and §7 (config) first — they are the two places where the spec's requirements and the current code are furthest apart.
