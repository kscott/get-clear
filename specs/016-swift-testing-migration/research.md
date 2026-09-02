# Phase 0 Research — Swift Testing Migration

Decisions that the survey left open, resolved here. Format: Decision / Rationale / Alternatives.

---

## R1 — "Compiles throughout" strategy

**Decision: per-target migration (survey §11 option C).** For each test target, one commit that (a) rewrites that target's `*Spec.swift` files and (b) removes that target's `Quick` / `Nimble` `.product(...)` entries from the root manifest — while `Package.swift` keeps the two `.package(url:)` declarations until the final target is done. The final commit removes those two lines and regenerates `Package.resolved`.

**Rationale**: `.package(url: Quick/Nimble)` staying declared means not-yet-migrated targets still resolve and compile. Dropping a migrated target's `.product` entries means that target no longer pulls Quick, so `swift test --filter <Target>` builds and runs on the CLT-only machine immediately after its commit. `swift build` stays green the whole way. Incremental local signal is the entire point on a machine that can't run XCTest.

**Alternatives**:
- *Big-bang the manifest first, migrate target-by-target with red `swift test` between steps* — loses the incremental signal locally; you're flying blind until the last target.
- *Migrate all 80 files with Quick still declared, remove at the end* — `swift test` only runnable in CI (which has XCTest) until the final commit; zero local signal; worst option for this situation.

**Manifest sequence** (target → the `.product` lines removed in its commit):

| Commit | Target | Files | Manifest edit |
|---|---|---|---|
| 1 | `GetClearKitTests` | 7 | tools-version→6.0, `swiftLanguageModes: [.v5]`, drop `GetClearKitTests` Quick/Nimble products |
| 2 | `AppleEventKitSupportTests` | 1 | drop its Quick/Nimble products |
| 3 | `AppleContactKitTests` | 1 | " |
| 4 | `ContactKitTests` | 3 | " |
| 5 | `TextLibTests` | 7 | " |
| 6 | `MailLibTests` | 11 | " |
| 7 | `ContactsLibTests` | 12 | " |
| 8 | `CalendarLibTests` | 19 | " |
| 9 | `RemindersLibTests` | 19 | " + `ReminderChangeError: Equatable` |
| 10 | — | — | remove the two `.package(url:)` lines; `swift package resolve`; `Package.resolved` → 0 pins |
| 11 | — | — | `git rm` the 5 `*-cli/Package.swift` + `Package.resolved` |
| 12 | — | — | docs + constitution |

Commit 1 is the pilot and gates everything.

---

## R2 — SwiftFormat 0.62.1 vs Swift Testing syntax  ✅ RESOLVED

**Decision: no SwiftFormat change needed.** Verified: `swiftformat --lint --config .swiftformat` (pinned 0.62.1) against a representative sample — nested `@Suite` structs, `@Test("…")`, `#expect(x == y)`, `#expect(x == nil)`, `#expect(throws: (any Error).self) { … }` trailing closure, `#expect(throws: MyError.case) { … }`, and `let err = #expect(throws:) { … }` — produces **zero macro-related changes**. The only lint hit is `sortImports` (an existing repo rule) wanting `import` lines alphabetized — which the migration follows anyway.

**Rationale**: freestanding macros (`#expect`, `#require`) parse through the same path as `#available` / `#Preview`; SwiftFormat 0.62.1 (Oct 2024) handles them and their trailing-closure form. `wrapAttributes` is unconfigured (default) and leaves `@Test` / `@Suite` inline.

**Note**: bumping `.swift-version` to `6.0` (R4) also feeds SwiftFormat a `--swift-version`, enabling a few version-gated rules that were dormant. These affect `Sources/` too, not just tests. The pilot's `swiftformat --lint .` run (full tree) catches any new `Sources/` finding; if one appears it is a one-line `.swiftformat` disable or a trivial fix, tracked in migration notes — not a blocker.

**Alternatives**: adding `Tests` to `.swiftformat --exclude` (would stop linting test formatting — undesirable, the hook is a real quality gate); bumping the SwiftFormat pin (interacts with #196 — unnecessary given it passes).

---

## R3 — The three fiddly assertion buckets: canonical forms

### Bucket 1 — `.to(throwError(SpecificError.case))` — error *value* equality (~10 sites)

Error types involved and their `Equatable` status (verified in source):

| Type | Conformance | Form |
|---|---|---|
| `TextError` (×3) | `Error, LocalizedError, Equatable` ✓ | `#expect(throws: TextError.notFound("xyzzy")) { … }` |
| `ReminderStoreError.notFound` | `Error, Equatable` ✓ | `#expect(throws: ReminderStoreError.notFound) { … }` |
| `CalendarStoreError.notFound` | `Error, Equatable` ✓ | `#expect(throws: CalendarStoreError.notFound) { … }` |
| `ReminderChangeError` (`.nothingToChange`, `.unrecognizedRecurrence`) | `Error` only ✗ | see R3-fix |

**Decision (R3-fix): add `Equatable` to `ReminderChangeError`.** One word — `enum ReminderChangeError: Error, Equatable` — matching its three sibling error types (`ReminderStoreError`, `CalendarStoreError`, `TextError` all already do). Behavior-preserving; the enum's cases are `nothingToChange` and `unrecognizedRecurrence(String)`, both trivially `Equatable`-synthesizable. This is FR-011's single permitted `Sources/` change, listed in migration notes.

**Rationale**: makes all ~10 bucket-1 sites the clean `#expect(throws: E.case)` form; the inconsistency (3 of 4 sibling errors are `Equatable`) was latent tech debt the migration tidies. The alternative — a case-matching closure for just the 2 `ReminderChangeError` sites — is more code for a worse result.

### Bucket 2 — `.to(throwError { (e: T) in expect(e.message).to(contain(…)) })` — inspect the thrown error (16 sites, all reminders handler specs, all on `ReminderHandlerError` which is a `struct` with a public `message`)

**Decision: the returned-error form.**
```swift
let err = #expect(throws: ReminderHandlerError.self) {
    try await handleX(args: […], store: store)
}
#expect(err?.message.contains("expected fragment") == true)
```
`#expect(throws:)` returns the caught error (`(any Error)?` narrowed by the type argument). No `Equatable` needed. Two `#expect`s replace one `throwError { }` — one for the type, one for the message.

**Alternative**: `#expect { try … } throws: { ($0 as? ReminderHandlerError)?.message.contains(…) == true }` — one call, but the failure message when the *type* is wrong is less clear (just "an error was thrown that didn't satisfy the closure"). The two-`#expect` form pinpoints which half failed.

### Bucket 3 — `fail("…")` inside `guard case` / `if case … else` (21 sites, 19 locations: `ChangeCommandSpec` ×6, `GetClearKitSpec` ×7, `ReminderStoreSpec`, `CalendarStoreSpec`, `DateParserSpec`)

**Decision: `Issue.record` in the `else` branch.**
```swift
guard case let .added(comps) = changes.due else {
    Issue.record("expected .added, got \(changes.due)")
    return
}
#expect(comps.year == 2026)   // continue asserting on the bound value
```
`Issue.record(_:)` is Swift Testing's direct `fail()` equivalent — records a failure at that source location, test continues or returns.

**Alternative**: hoist to a Bool — `let matched = if case .added = changes.due { true } else { false }; #expect(matched)` — loses the ability to bind and assert on associated values in the same test, forcing a second pattern match. Rejected where the test inspects the bound value (most `ChangeCommandSpec` cases do).

For the `parseArgs` cases in `GetClearKitSpec` (`.empty` / `.help` / `.version` / `.command(...)`) that only check *which* case, the Bool-hoist form is fine and shorter — allow either, `Issue.record` preferred for consistency.

---

## R4 — `.swift-version` and `swift-tools-version` values

**Decision**: `swift-tools-version: 6.0` (the floor Swift Testing integration needs); `.swift-version` → `6.0` (matching the floor, not the installed 6.3.3).

**Rationale**: `6.0` states the true minimum. Toolchain-selection tools (swiftenv/swiftly) reading `.swift-version: 6.0` will accept any ≥6.0 toolchain including the installed 6.3.3. Pinning `6.3.3` would over-constrain contributors/CI to an exact patch. `swift-tools-version` and `.swift-version` are different mechanisms (manifest API level vs toolchain selection) but keeping them both at `6.0` is coherent and minimal.

**Alternatives**: `.swift-version: 6.3` (matches reality, slightly over-specified); leaving `.swift-version: 5.9` (contradicts the manifest floor — a tool could pick a 5.x toolchain that can't parse the 6.0 manifest).

---

## R5 — Language-mode pin: package-level vs per-target

**Decision: `swiftLanguageModes: [.v5]` as an argument to `Package(...)` in the root manifest.** One line, applies to every target.

**Rationale**: 23 targets in the root manifest. A per-target `swiftSettings: [.swiftLanguageMode(.v5)]` means 23 edits and 23 chances to miss one — and a missed target silently compiles in Swift 6 mode (default at tools ≥ 6.0), changing `Sendable` enforcement on the non-`Sendable` `final class` test doubles and possibly overload resolution in `Sources/`. The package-level form is atomic.

**Verified**: no target currently sets `swiftSettings`, `swiftLanguageVersions`, `unsafeFlags`, `.enableUpcomingFeature`, or `.enableExperimentalFeature` — nothing to reconcile. `linkerSettings: [.linkedFramework(...)]` on the EventKit/Contacts/AppKit boundary targets is unaffected by language mode.

**Alternatives**: per-target pins (rejected — error-prone); moving to Swift 6 language mode (out of scope per spec — that's a separate migration with real `Sendable` work).

---

## R6 — `beforeEach` → suite initialization

**Decision**: `@Suite` types are `struct`s; a `beforeEach` fixture becomes a stored `let`/`var` initialized inline or in `init()`.

- **28 trivial hooks** (`store = Spy…()`): `struct AddHandlerTests { let store = SpyStore() … }`. Swift Testing constructs a fresh suite instance per `@Test`, so each test gets its own `store` — the isolation the closure-captured `var` lacked.
- **6 `ActivityLogSpec` hooks**: `struct FileCreation { let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("gc-test-\(UUID().uuidString)") ; init() throws { try ActivityLog.write(…, baseDirectory: tempDir) } }`. Per-instance `tempDir`, per-instance write. The one deviation (`context("malformed lines")` using a closure-local `let`) normalizes to the same shape.

**Rationale**: per-`@Test` instance construction is Swift Testing's built-in isolation model — it replaces `beforeEach` exactly, with no shared state possible by construction.

**Alternative**: `final class` suites with an `init()` — needed only if a test mutates `self` across... no, each `@Test` still gets a fresh instance. `struct` is the default; use `final class` only where a test double must be a reference type held by the suite (it can still be a `let` in a struct). Default to `struct`.

---

## R7 — Async

**Decision**: `AsyncSpec` → ordinary `@Suite`; each async `it` → `@Test func …() async throws`. `await expect { try await … }.to(throwError())` → `await #expect(throws: …) { try await … }`.

**Rationale**: Swift Testing has no async/sync suite split — any `@Test` may be `async`. The survey found the entire async surface is `try await handleX(…)` and the async `throwError` form; no continuations, `Task`, actors, or `@MainActor`. Direct translation.

---

## R8 — Suite type naming (option A, locked with Ken)

**Decision**: drop the tool prefix. `CalendarAddHandlerSpec` → `AddHandlerTests`, `MailFindHandlerSpec` → `FindHandlerTests`, etc. Every target lands on bare `<Thing>Tests`. Filenames stay `*Spec.swift` (no rename).

**Rationale**: the prefix existed solely to dodge Quick's ObjC-runtime class-name collisions across targets. Swift Testing suites are module-scoped Swift types — `RemindersLibTests.AddHandlerTests` and `ContactsLibTests.AddHandlerTests` don't collide. Uniform unprefixed names are the clean end state; the renames are free since the files are being rewritten anyway. `*Spec.swift` filenames kept to avoid 80 renames + git-history churn for no functional gain.

**Type name suffix**: `Tests`, not `Spec`. `Spec` was BDD/Quick vocabulary; `Tests` is the Swift Testing norm and matches the (kept) `*Spec.swift` filename loosely enough. Not worth bikeshedding — `Tests`.

---

## R9 — Coverage

**Decision**: coverage keeps working unchanged in mechanism; only the *documented invocation* updates.

- `swift test --enable-code-coverage` still emits `.build/…/debug/codecov/default.profdata` (SwiftPM behavior, framework-independent).
- The test-bundle binary that `llvm-cov` needs: derive it from `swift build --show-bin-path` rather than the hardcoded `…PackageTests.xctest/Contents/MacOS/…` (which is the XCTest-bundle shape and will change).
- `swift test --show-codecov-path` prints the profdata path directly.

**Repo impact**: none — no script or workflow references coverage paths (`review.md:10` is prose). **Out-of-repo**: `~/.claude/…/project_coverage_tooling.md` (user memory, cross-machine via dotfiles) hardcodes the old path — flag to Ken to update; not a repo change, not blocking.

---

## R10 — Vestigial `*-cli/` cleanup scope

**Decision**: `git rm` the five `*-cli/Package.swift` and `*-cli/Package.resolved`. Leave `*-cli/Sources/` and `*-cli/Tests/` (the real code, referenced by the root manifest). Stale `*-cli/.build/` are gitignored (not tracked) — no action. Orphaned `*-cli/.github/` old workflows: `git rm -r` them in the same cleanup commit — they're dead (GitHub only reads `.github/` at repo root) and misleading.

**Rationale**: the manifests are pure liability — a `cd reminders-cli && swift build` would resolve `GetClearKit` from GitHub `main` and mislead. Deleting removes the trap. The `.github/` subdirs are the same kind of dead weight.

**Alternative**: keep them with a "not a build input" comment (rejected — a deleted file is clearer than a commented one, and nothing references them).
