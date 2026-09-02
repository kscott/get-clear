# Pre-Plan Survey — Swift Testing Migration (spec 016)

Two parallel exploration passes (test-suite patterns; manifests & seams). Findings that the planner should not have to rediscover.

---

## 1. Scope is smaller than the spec's framing

| Spec framing | Reality |
|---|---|
| "6 Package.swift manifests" | **1 manifest matters.** The root `/Package.swift` is the only file SwiftPM reads. Its test targets point directly at `<tool>-cli/Tests/<Tool>LibTests`. The five `*-cli/Package.swift` are **vestigial** pre-monorepo leftovers (#34) — never a build input; a standalone `cd <tool>-cli && swift build` would even resolve `GetClearKit` from GitHub `main`, not the local tree. Decision for the plan: **edit them for consistency, or delete them.** Deleting is defensible and removes a latent trap. |
| "no change to code under test" | **Holds fully.** Both passes independently confirmed: `ActivityLog.write` / `ActivityLogReader.entries` / `entriesForDisplay` already take an injectable `baseDirectory:` (and `now:`), and every ActivityLog test already passes a unique `UUID()` temp dir. **FR-011's production-change exception is not needed.** |
| FR-019 "the constitution … MUST be updated" | `.specify/memory/constitution.md` has **no test-framework reference at all** (105 lines, full read). Neither does `design.md` or `README.md`. FR-019's constitution clause is a no-op unless the plan chooses to *add* a testing principle. Recast FR-019 to the real targets below. |

**Real doc-update surface (FR-018/019/020):**
- `CLAUDE.md:44` — the testing paragraph (primary rewrite), `CLAUDE.md:114` — "Active Technologies" bullet (`Swift 5.9 … + Quick + Nimble`)
- `review.md:92,94,96` — "Framework: Quick + Nimble", "Structure: describe → context → it", "unimplemented behavior gets an `it` that asserts nil"
- `ARCHITECTURE.md:55, :98, :148` — Quick-specific constraints (see §5); `:152` test count; `:166` coverage baseline
- `review.md:9,10` and `CLAUDE.md:70` — `swift test` command references — **stay valid, no change**

---

## 2. The complete `#expect` translation table (from actual grep counts over 80 files)

Equality is **always** the `==` operator form — `equal()` / `beTrue()` / `beFalse()` / `beGreaterThan` / `beCloseTo` are **never used** (verified zero hits).

| Nimble form | Count | → Swift Testing |
|---|---|---|
| `expect(x) == y` | ~631 | `#expect(x == y)` |
| `expect(x) == true` | 102 | `#expect(x)` |
| `expect(x) == false` | 35 | `#expect(!x)` |
| `expect(x) == nil` | 3 | `#expect(x == nil)` |
| `expect(x) != y` | 3 | `#expect(x != y)` |
| `expect(x) > / < / <= y` | 7 | `#expect(x > y)` … |
| `.to(beNil())` | 35 | `#expect(x == nil)` |
| `.toNot(beNil())` / `.notTo(beNil())` | 17 | `#expect(x != nil)` or `try #require(x)` |
| `.to(beEmpty())` | 22 | `#expect(x.isEmpty)` |
| `.toNot(beEmpty())` | 8 | `#expect(!x.isEmpty)` |
| `.to(contain(one))` | 191 | `#expect(x.contains(one))` — never multi-arg |
| `.toNot/.notTo(contain(one))` | 26 | `#expect(!x.contains(one))` |
| `.to(haveCount(n))` | 8 | `#expect(x.count == n)` |
| `.to(beginWith(p))` | 10 | `#expect(x.hasPrefix(p))` |
| `.toNot(beginWith(p))` | 3 | `#expect(!x.hasPrefix(p))` |
| `.to(throwError())` bare (sync/async) | 32 | `#expect(throws: (any Error).self) { … }` |
| `.to(throwError(errorType: T.self))` | 7 (all RemindersLibTests) | `#expect(throws: T.self) { … }` |
| `.notTo(throwError())` | 4 | `#expect(throws: Never.self) { … }` |

**The three fiddly buckets (≈47 sites) — this is where the plan needs a decision:**

1. **`.to(throwError(SpecificError.case))`** — value equality on the thrown error (~10). Errors: `TextError` (×3), `ReminderChangeError` (`.nothingToChange`, `.unrecognizedRecurrence`), `ReminderStoreError.notFound`, `CalendarStoreError.notFound`. → `#expect(throws: SpecificError.case)` **requires the error be `Equatable`.** Plan must confirm each conforms, or fall back to bucket 2's form.
2. **`.to(throwError { (e: T) in expect(e.message).to(contain(…)) })`** — closure inspects the thrown error (16, spread across reminders handler specs). → `let err = #expect(throws: T.self) { … }; #expect(err?.message.contains(…) == true)`.
3. **`fail("…")` inside `guard case` / `if case … else`** (21 sites, 19 pattern-match locations) — asserting an enum case matched. Files: `ChangeCommandSpec` (×6), `GetClearKitSpec` (×7, on `parseArgs` → `.empty/.help/.version/.command`), `ReminderStoreSpec:82`, `CalendarStoreSpec:42`, `DateParserSpec:99`. → `guard case … else { Issue.record("…"); return }` **or** hoist to a Bool and `#expect(matched, "…")`.

Pick one canonical form for each of buckets 2 and 3 in the plan so the 80-file sweep is mechanical.

---

## 3. `beforeEach` — 34 hooks, 2 shapes

- **28 of 34** (across 28 files): literally `var store: Spy…!` at `spec()` scope + `beforeEach { store = Spy…() }`. One line. → stored property on the `@Suite` type (fresh per `@Test` instance). This closure-captured `var` is the *only* non-parallel-safe thing in those files; converting it to a per-instance property fixes it for free.
- **6 of 34**: all in `Tests/GetClearKitTests/ActivityLogSpec.swift` — real filesystem I/O, but each already builds a unique `FileManager.default.temporaryDirectory/gc-test-<UUID>` and passes it as `baseDirectory:`. Parallel-safe once the `var tempDir` becomes a per-instance `let`. One deviation to normalize: `context("malformed lines")` (`:179`) uses a closure-local `let tempDir` while siblings use the context `var`. No temp-dir cleanup exists anywhere (pre-existing `$TMPDIR` litter — cheap to add a `deinit`, out of scope to require).
- **Category C (env var / static mutation / shared resource): none.** Verified zero `setenv`/`getenv`/`ProcessInfo.environment`/`NSHomeDirectory` and zero real Apple stores (`EKEventStore`, `CNContactStore`, `Apple*Store`) in any test.

**`@Suite(.serialized)` is likely needed on zero suites.** `ActivityLogSpec` is the only candidate and the evidence says it's already isolated; `.serialized` there is a cost-free belt-and-suspenders if the plan wants it.

---

## 4. Async — clean

32 `AsyncSpec` files, all for one reason: an `it` closure needs `await`. The entire async surface is `try await handleX(…)` and `await expect { try await … }.to(throwError())` (53 `await expect` sites). **Zero** `withCheckedContinuation`, `Task`, `Task.sleep`, `actor`, `@MainActor`, `DispatchQueue`, `AsyncStream` in any test. → `@Test func …() async throws { … }` + `await #expect(throws:) { … }`. No isolation to reason about.

---

## 5. Toolchain: `swift-tools-version` 5.9 → 6.0

- **No manifest API in use breaks at 6.0.** Manifests use only `Package`, `.macOS(.v14)`, `.library`/`.executable`, `.package(url:from:/branch:)`, `.target`/`.executableTarget`/`.testTarget`, `.product`, `.linkedFramework`, `exclude:`.
- **Default language mode flips to v6 at tools ≥ 6.0.** No target sets anything today. **Highest compile-break risk in the whole migration**: miss a target and it silently compiles Swift 6 mode — changes `Sendable` enforcement (the non-`Sendable` `final class` spies/mocks), overload resolution, existential-`any`.
  - **Mitigation: package-level `swiftLanguageModes: [.v5]`** — one argument on `Package(...)`, covers every target in that manifest. Beats 23 per-target `swiftSettings: [.swiftLanguageMode(.v5)]`.
- **`Package.resolved` regenerates**: schema `"version": 2` → `3`, adds per-pin `originalHash`. After Quick/Nimble removal the root `Package.resolved` has **zero pins** — SwiftPM writes `{"pins":[],"version":3}` or removes the file. Diff is total; that's expected.
- **`.swift-version` file at repo root** contains `5.9` (no newline). Read by swiftenv/swiftly, not by CI. Decide: bump to `6.0` / toolchain version, or leave. Flag either way.
- Root and sub-manifests have **no ordering constraint** — bumping the root alone makes `swift build`/`swift test` work.

---

## 6. Dependency graph that disappears

Root `Package.resolved` has 7 pins, **all transitive from Quick/Nimble, none used by first-party code** (grep of `Sources/` for `ArgumentParser`/`Algorithms`/`Numerics`/`RegexBuilder` = zero):

`quick` 7.6.2 · `nimble` 13.8.0 · `cwlcatchexception` 2.2.1 · `cwlpreconditiontesting` 2.2.2 *(this pair is the XCTest linker via `CwlMachBadInstructionHandler`)* · `swift-algorithms` 1.2.1 · `swift-argument-parser` 1.7.1 · `swift-numerics` 1.1.1

`.build/checkouts/` holds exactly these 7. After removal, **nothing in the graph links XCTest** — verified: zero `import XCTest` in `Sources/`, no compiler-plugin/macro deps, no snapshot libs, no build-tool plugins, no resource bundles, no `unsafeFlags`, no `.enableUpcomingFeature`. FR-003 is genuinely achievable.

---

## 7. SwiftFormat / SwiftLint

- **SwiftLint excludes every `Tests/` dir** (`.swiftlint.yml:10-15`) — it will never see a migrated test file. `@Test`/`@Suite`/`#expect` macro syntax is a non-issue. Two Quick-tuned settings (`static_over_final_class` disabled `:27`, `function_body_length` error 400 `:79`) go stale but only ever affected `Sources/` — re-tightening them risks new warnings on production code, so treat as **separate cleanup, not this migration**.
- **SwiftFormat does NOT exclude `Tests/`** (`.swiftformat:25` lists only `.build`). `swiftformat .` reformats all 80 rewritten files, and the **active pre-push hook** (`.githooks/pre-push`, `core.hooksPath=.githooks`) runs `swiftformat --lint .` and **blocks the push** on any violation. The hook does **not** run tests, so a partially-migrated branch still pushes.
  - **Action for the plan: lint-check one migrated sample file with the pinned SwiftFormat 0.62.1 (Oct 2024) early.** Freestanding macros (`#expect`, `#require`) share the parser path of `#available`/`#Preview` and are generally safe; the thing to verify is the **trailing-closure form** `#expect(throws:) { … }` and that `wrapAttributes` (unconfigured → default) doesn't relocate `@Test`/`@Suite`. If it chokes: bump the pin (interacts with #196) or add `Tests` to `--exclude` (interacts with the hook's coverage of test formatting).

---

## 8. ARCHITECTURE.md entries that change

| Line | Entry | Fate |
|---|---|---|
| `:55`, `:148` | "Quick registers spec classes via the ObjC runtime with no module prefix … two spec classes with the same name in different test targets collide silently … all spec classes must be prefixed with their tool" | **Constraint disappears.** Swift Testing suites are module-scoped Swift types; `AddHandlerSpec` in `ContactsLibTests` and `RemindersLibTests` no longer collide. Prefix convention (`CalendarAddHandlerSpec`, `MailFindHandlerSpec`) becomes optional — keeping names as-is is lowest-churn; rewrite the entries either way. |
| `:98` | "`SendHandlerSpec` uses `AsyncSpec` (not `QuickSpec`) — required for async `it` closures" | `AsyncSpec` is a Quick type; `@Test … async` is universal. Update. |
| `:152` | "987 total suite tests, 0 failures" | Count shifts. Baseline of record elsewhere: **1,032 tests / 80.66% line coverage** (`cross-tool-review-2026-04-29.md`). Survey counts **1,073 `it()` blocks** now. Reconcile and restate. |
| `:166` | "RemindersLib reached 91.4% line coverage … ~97.8%" | Coverage parity reference for SC-010. |
| **new** | FR-020 entry | Nothing to supersede (the 2026-04-11 TestRunner→Quick move `99a20f6` was **never logged**). New entry should note the round-trip: hand-rolled harness (to avoid XCTest/Xcode) → Quick+Nimble (traded it back) → Swift Testing (solves it properly), and the CLT-dropped-XCTest cause. |

---

## 9. Spec 015 artifacts (FR-022) — doc-only, on the 015 branch

`specs/015-argument-shape/` `spec.md` / `contracts/*` / `data-model.md` / `checklists/` are **framework-clean**. All references are in `tasks.md`, `plan.md`, `quickstart.md`, `research.md`:

- `tasks.md`: T001 ("pass count"), T003/T003a/T005/T007/T015-T021/T023/T026/T027/T032 (all name `*Spec.swift`, "`describe`", "one assertion per `it`", "one `it` per `ArgumentError` case"), checkpoints `swift test --filter …` (— `--filter` still works)
- `plan.md:13,15` ("Primary Dependencies: … Quick + Nimble", "Testing: Quick + Nimble via `swift test`"), file-tree blocks at `:70-73` and `:98-110`, "Step 2/Step 4" prose, `:194` "0 failures"
- `quickstart.md:82-93` — a Quick-syntax code block to rewrite to `@Suite`/`@Test`/`#expect(throws:)`
- `research.md:11` — "with a Quick spec" → "with a Swift Testing suite"

**Cannot be done on the 016 branch** — those files aren't there. Options: (a) a doc-only commit on `015-argument-shape` now, or (b) fold into 015's first implementation task. Recommend (a) so 015 is coherent whenever it resumes.

---

## 10. Test-support layout (for planning the per-target sweep)

- **Shared, cross-target**: `Tests/ContactTestSupport/` — a plain `.target` (not test target) in the root manifest, used by `ContactKitTests`, `ContactsLibTests`, `MailLibTests`. `SpyContactStore.swift` (`public final class`), `Fixtures.swift` (`public func makeContact` + 5 `public let` fixtures). Not a `*Spec.swift` — **not** part of the 80, but its `public` types are consumed by files that are.
- **Per-target fixtures** (co-located, not shared): `reminders-cli/…/RemindersLibTests/Fixtures.swift` (`SpyStore`), `calendar-cli/…/CalendarLibTests/Fixtures.swift` (`SpyCalendarStore`), `mail-cli/…/MailLibTests/MailTestSupport.swift` (`SpyMailClient` with `var shouldThrow`).
- **File-private doubles**: `text …/SendHandlerSpec.swift` (`SpyMessageSender`), `reminders …/ReminderStoreSpec.swift` (`MockStore` — note RemindersLibTests has *two* `ReminderStore` doubles, `SpyStore` + `MockStore`).
- All doubles are `final class` with mutable `var` arrays, **not `Sendable`** — fine under pinned Swift 5 mode, would warn under v6 (→ §5).

---

## 11. Suggested sequencing (planner to confirm)

1. **Prove the toolchain first** — on the branch: bump root `swift-tools-version` to 6.0 + `swiftLanguageModes: [.v5]`, remove Quick/Nimble from the root manifest, and migrate the **smallest target, `GetClearKitTests` (7 files, 212 `it`s, includes `ActivityLogSpec`)**. `swift build` + `swift test --filter` on this machine (CLT-only) must go green. This single step validates: 6.0 bump, language-mode pin, XCTest-free build, the `beforeEach`→`init` pattern, and the ActivityLog parallel question — all at once.
2. **Establish the canonical forms** for the three fiddly buckets (§2) as part of step 1, in a short migration-notes doc.
3. **Roll through the other 8 test targets**, one per commit, de-Quick-ing each in the manifest as it's finished so `swift test --filter <Target>` runs progressively.
4. **Remove Quick/Nimble + the 7 pins entirely**; regenerate `Package.resolved`.
5. **Docs** (`CLAUDE.md`, `review.md`, `ARCHITECTURE.md`) + `.swift-version` decision + the sub-manifest decision (edit vs delete).
6. **Coverage**: rewrite `~/.claude/…/project_coverage_tooling.md` to `swift test --show-codecov-path` + `swift build --show-bin-path` (user memory, cross-machine via dotfiles — flag to Ken).
7. **Separately, on `015-argument-shape`**: the FR-022 doc sweep.

Each of steps 1 and 3 is independently verifiable (`swift test --filter`), and `swift build` stays green throughout.

---

## 12. Risk register

| Risk | Likelihood | Mitigation |
|---|---|---|
| Missed a target's Swift 5 mode pin → surprise Swift 6 compile break in `Sources/` | Medium | Use package-level `swiftLanguageModes: [.v5]`, not per-target |
| SwiftFormat 0.62.1 mangles `#expect { }` / `@Test` → pre-push hook blocks | Medium | Lint-check a sample in step 1; fall back to `--exclude Tests` or pin bump (#196) |
| `throwError(SpecificError.case)` errors aren't `Equatable` | Medium | Confirm per type in step 2; else use returned-error + `#expect` form |
| `fail()` in `guard case` conversions inconsistent across 21 sites | Low | One canonical form decided in step 2 |
| Coverage bundle path changes, `llvm-cov` invocation breaks | Low | `swift test --show-codecov-path` (FR-024); `.profdata` location unchanged |
| Vestigial sub-manifests drift / mislead a future contributor | Low | Delete them, or add a one-line "not a build input" comment |
| Test count / coverage baseline in `ARCHITECTURE.md` is already stale (987 vs 1032 vs 1073) | — | Re-measure and restate as part of FR-020 |
