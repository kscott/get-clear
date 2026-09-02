# Feature Specification: Migrate Test Suite to Swift Testing

**Feature Branch**: `016-swift-testing-migration`
**Created**: 2026-09-01
**Status**: Draft
**Input**: User description: "Migrate the entire test suite from Quick + Nimble to Swift Testing. Quick's QuickSpec is an XCTestCase subclass so every test transitively depends on Apple's XCTest framework, which ships only with full Xcode; a recent Command Line Tools update removed XCTest so `swift test` no longer builds locally. Swift Testing has no XCTest dependency and runs from the plain toolchain on macOS and Linux. Scope: all 80 Spec.swift files across GetClearKit and the five CLI tools, rewriting to Suite/Test/expect, bumping swift-tools-version 5.9 to 6.0 while pinning Swift 5 language mode, removing Quick and Nimble, updating CLAUDE.md and the constitution. No change to code under test. Lands before spec 015 is implemented."

---

## Background

Get Clear's tests are written in Quick + Nimble. `QuickSpec` is a subclass of `XCTestCase`, so every spec file transitively links Apple's **XCTest** framework. On macOS, XCTest is supplied only by a full **Xcode** install — the standalone Command Line Tools do not carry it. This machine runs the Command Line Tools with no Xcode (CLT 26.6, installed 2026-07-10). A CLT update between April and July 2026 stopped shipping XCTest, and `swift test` now fails to build locally:

```
QuickSpecBase.h:2:9: fatal error: 'XCTest/XCTest.h' file not found
```

Tests still pass in CI, because GitHub's `macos-latest` runners include Xcode. But locally — where the developer and Claude both work — the suite cannot be built or run at all.

This is a regression the project has hit before. Until 2026-04-11 (commit `99a20f6`) the tests used a hand-rolled `TestRunner` harness precisely to avoid the XCTest/Xcode dependency. Adopting Quick + Nimble that day traded the dependency back in. The suite has never used plain XCTest directly, and it uses none of Quick's advanced features — `sharedExamples`, `itBehavesLike`, `waitUntil`, `toEventually`, and custom matchers are all absent. It uses Quick + Nimble as a nicer XCTest: `describe` / `context` / `it` plus `expect(...)` matchers.

**Swift Testing** (the `Testing` library) ships inside the Swift toolchain itself. It has no XCTest dependency and runs `swift test` from the plain Command Line Tools on macOS, and on Linux. It is also the direction Apple's tooling is moving. Migrating the suite to it restores local test execution without an IDE, permanently.

This migration should land before spec **015 (argument shape)** is implemented, so that feature's ~15 new test files are written in Swift Testing from the start rather than in Quick and converted later.

---

## User Scenarios & Testing *(mandatory)*

The actors are the **developer** and **Claude**, both of whom run `swift test` on a Command Line Tools–only machine, and **CI**, which runs it on every merge to `main`.

### User Story 1 — The suite runs locally with no Xcode (Priority: P1)

On a machine with only the Command Line Tools installed — no `Xcode.app` — the developer or Claude runs `swift test` and the entire suite builds and executes.

**Why this priority**: This is the reason for the feature. Right now the suite cannot run locally at all. Every other outcome is secondary to restoring that.

**Independent Test**: On this machine (`xcode-select -p` → `/Library/Developer/CommandLineTools`), run `swift build` then `swift test`. The build succeeds and every test executes with a pass/fail result — no `XCTest/XCTest.h` error, no skipped targets.

**Acceptance Scenarios**:

1. **Given** a Command Line Tools–only machine, **When** `swift test` is run from the repo root, **Then** all test targets compile and every test runs to a verdict.
2. **Given** the migration is complete, **When** `grep -r "import Quick\|import Nimble"` is run over the repo, **Then** there are zero matches outside `.build/`.
3. **Given** the migration is complete, **When** `Package.resolved` is inspected, **Then** neither Quick nor Nimble appears, and no dependency in the graph pulls XCTest.

---

### User Story 2 — Every test's behavior is preserved (Priority: P1)

Each `it` block becomes exactly one Swift Testing test with the same assertion and the same intent. No test is dropped, merged away, weakened to `assert(true)`, or silently skipped. Test coverage after the migration equals coverage before.

**Why this priority**: A migration that quietly loses assertions is worse than not migrating — it removes the safety net while looking green. Behavioral parity is non-negotiable.

**Independent Test**: Count `it(` / `func test` occurrences before and `@Test` occurrences after, per test target. The counts match (allowing for documented consolidations where two `it`s asserted the identical thing). Spot-check ten translated tests against their originals: same input, same expected value, same matcher semantics.

**Acceptance Scenarios**:

1. **Given** a Quick `it("returns nil for an empty string") { expect(parse("")).to(beNil()) }`, **When** it is migrated, **Then** the result is a single `@Test` asserting `parse("") == nil` with an equivalent description.
2. **Given** a spec with a `beforeEach` that builds a fresh fixture, **When** it is migrated, **Then** each test gets that fixture built fresh (via the suite's initializer), with no state leaking between tests.
3. **Given** an `AsyncSpec` whose `it` blocks `await` an async API, **When** it is migrated, **Then** the tests are `async` and exercise the same calls.
4. **Given** a test that asserted a specific error was thrown, **When** it is migrated, **Then** it still asserts that same error type or value is thrown.
5. **Given** the full suite before and after, **When** the pass count is compared, **Then** the number of independent assertions is equal (± documented consolidations).

---

### User Story 3 — The project's test conventions are re-stated for Swift Testing (Priority: P2)

`CLAUDE.md` and the constitution currently mandate Quick + Nimble and describe the `describe` → `context` → `it` structure. After the migration they describe the Swift Testing equivalent — `@Suite` nesting, `@Test` with a natural-sentence description, one behavior per test — so that new tests (015's included) are written the new way without guesswork.

**Why this priority**: The written standard is what the next feature follows. If it still says "Quick + Nimble," the drift starts again immediately.

**Independent Test**: Read the testing section of `CLAUDE.md` and the constitution. Neither mentions Quick or Nimble as the framework. Both describe Swift Testing structure, the one-behavior-per-test rule, natural-sentence descriptions, and one-test-file-per-source-file — the conventions that carry over unchanged.

**Acceptance Scenarios**:

1. **Given** `CLAUDE.md`, **When** its testing section is read, **Then** it names Swift Testing as the framework and shows the `@Suite` / `@Test` / `#expect` shape.
2. **Given** the constitution, **When** any test-framework reference is read, **Then** it is consistent with `CLAUDE.md`.
3. **Given** the carried-over conventions (one behavior per test, natural-sentence descriptions, one test file per source file, edge cases are first-class), **When** the updated docs are read, **Then** each is still stated.

---

### User Story 4 — Parallel execution introduces no flakiness (Priority: P2)

Swift Testing runs tests in parallel by default; Quick ran them serially. After the migration, running the suite repeatedly produces the same result every time. No test depends on execution order or on another test's side effects.

**Why this priority**: A flaky suite erodes trust as fast as a missing one. Parallel execution is a benefit of the move, but only if the suite is actually isolated.

**Independent Test**: Run `swift test` five times in a row on the same checkout. Identical results each run — same passes, same failures, no intermittent errors. Run once more with parallelism disabled; the result is the same set of passes/failures.

**Acceptance Scenarios**:

1. **Given** the migrated suite, **When** it is run five consecutive times, **Then** the pass/fail set is identical every time.
2. **Given** a suite whose tests produce a process-global side effect (for example, writing the activity log to a real file), **When** the suite runs in parallel with the rest, **Then** those tests neither corrupt shared state nor fail intermittently — the side effect is directed somewhere test-controlled, or the suite is marked to run serially.
3. **Given** any two tests, **When** one is run without the other, **Then** its result is unchanged.

---

### User Story 5 — CI keeps passing, unchanged (Priority: P3)

The CI workflow still runs `swift build` and `swift test` and still goes green. The migration requires no change to `.github/workflows/`.

**Why this priority**: CI is the backstop that has been masking the local breakage. It must not regress, but it needs no active work — this story is a guardrail, not a task.

**Independent Test**: Push the branch, open a PR, let CI run. `swift build` and `swift test` both pass. Diff `.github/workflows/` — no changes.

**Acceptance Scenarios**:

1. **Given** the migration branch, **When** CI runs, **Then** `swift test` passes on the GitHub runner.
2. **Given** the migration, **When** `.github/workflows/` is diffed against `main`, **Then** it is unchanged.

---

### Edge Cases

- **A Nimble matcher with no direct `#expect` form** (e.g. `beCloseTo` for floating-point). It is rewritten as an explicit comparison (`abs(a - b) < tolerance`) that asserts the same thing. If any matcher genuinely cannot be expressed, it is called out rather than dropped.
- **A `beforeEach` that mutates shared/static state** rather than building a local fixture. The migration surfaces it: the state is made local to the suite, or the suite is serialized. This is the one place the migration may touch non-test code — narrowly, to make a side effect test-directable — and any such change must be behavior-preserving.
- **A test that relied on Quick's serial execution** (implicit ordering, a leaked fixture). It is fixed to be independent, not preserved as-is.
- **The `swift-tools-version` bump to 6.0 changes a manifest default.** With tools-version ≥ 6.0 the default language mode becomes v6; the package pins Swift 5 mode via the package-level `swiftLanguageModes: [.v5]` argument (one line, all targets) so the code under test compiles with unchanged semantics. Bumping `.swift-version` to 6.0 also feeds SwiftFormat a version, which enables a few dormant rules across the whole tree — the pilot's tree-wide `swiftformat --lint` catches any new `Sources/` finding.
- **A partially-migrated state on the branch.** While any target still imports Quick, the whole-suite `swift test` cannot build locally. Migrating and de-Quick-ing one target at a time keeps `swift build` green throughout; whether `swift test` can also run per-target locally before Quick is fully removed depends on whether `swift build --build-tests --target <T>` compiles one target in isolation on the CLT — the pilot determines this (tasks T006). If it cannot, per-target verification is CI-only until the final Quick-removal commit, and the first full local `swift test` is at that point.
- **Spec 015's artifacts name `*Spec.swift` files and Quick patterns.** 015 is not yet implemented, so this is a documentation fix in its `tasks.md` / contracts, folded in or done as 015's first implementation step.
- **`swift test` filter and IDE integration.** `swift test --filter` still works with Swift Testing. No editor/IDE tooling depends on Quick.
- **Code coverage tooling.** `swift test --enable-code-coverage` instruments the code under test, not the framework, so it keeps working — but the test-bundle binary the coverage run points `llvm-cov` at may change name from the XCTest form. Any hardcoded path is updated (FR-024).
- **Nimble's failure output was descriptive.** Swift Testing's `#expect` failure output must be at least as informative — where a bare `#expect(a == b)` would be cryptic, the test includes a message or uses `#require`.

---

## Requirements *(mandatory)*

### Functional Requirements — The migration

- **FR-001**: Every `*Spec.swift` file in the repository MUST be rewritten to Swift Testing: `@Suite` types, `@Test` functions, `#expect` / `#require` assertions. After the migration, no test source file imports `Quick` or `Nimble`.
- **FR-002**: Quick and Nimble MUST be removed from the root `Package.swift` — from `dependencies` and from every one of the nine test targets that lists them — and the root `Package.resolved` regenerated with no Quick/Nimble pins and none of their seven transitive pins.
- **FR-002a**: The five `*-cli/Package.swift` manifests and their `Package.resolved` files, which are vestigial pre-monorepo leftovers that SwiftPM never reads, MUST be deleted. The `*-cli/Sources/` and `*-cli/Tests/` directories (which the root manifest references by path) are untouched. Stale `*-cli/.build/` directories and orphaned `*-cli/.github/` workflow files MAY be removed in the same change.
- **FR-003**: No dependency remaining in the resolved graph may link XCTest. `swift test` MUST build and run with only the Command Line Tools installed (no `Xcode.app`, `xcode-select -p` pointing at `CommandLineTools`).
- **FR-004**: Each `it` / harness test case MUST map to exactly one `@Test`. Two `it`s that asserted the identical behavior on the identical input MAY be consolidated to one `@Test`, and each such consolidation MUST be listed in the migration's notes. No other reduction in assertions is permitted.
- **FR-005**: `describe` and `context` groupings MUST be preserved as nested `@Suite` types, so the test tree reads the same.
- **FR-006**: `beforeEach` setup MUST be preserved as per-test fixture construction (a suite initializer or equivalent) that runs fresh for every test, with no state shared between tests.
- **FR-007**: Async tests MUST remain async — `@Test` functions that `await` the same APIs the `AsyncSpec` `it` blocks awaited.
- **FR-008**: Error-throwing assertions MUST preserve their specificity: a test that asserted a particular error type or value MUST still assert that particular error, not merely "something was thrown." Where a test asserted a specific error *value*, the error type must be `Equatable` for `#expect(throws: Error.case)`; where it is not, the returned-error-plus-`#expect` form is used.
- **FR-009**: Test descriptions MUST remain natural-English sentences describing the behavior (the existing convention), carried onto `@Test("…")` and `@Suite("…")`.
- **FR-010**: The one-test-file-per-source-file rule MUST hold: each migrated file corresponds to the same single source file. Filenames keep the `*Spec.swift` form (no mass rename). Suite **type names** drop the tool prefix that existed only to avoid Quick's Objective-C class-name collisions (`CalendarAddHandlerSpec` → `AddHandlerTests`); every target lands on uniform, unprefixed type names.
- **FR-011**: Production code (anything under `Sources/`) is not touched, with **one** listed exception: `ReminderChangeError` gains `Equatable` conformance (`reminders-cli/Sources/RemindersLib/ReminderChangeParsing.swift`) — one word, behavior-preserving, matching its three sibling error types (`ReminderStoreError`, `CalendarStoreError`, `TextError` all already conform). This lets the ~2 `#expect(throws: ReminderChangeError.case)` assertions use the clean value form instead of a case-matching closure. The change is recorded in the migration notes. No other `Sources/` change is permitted; the survey confirmed the suite's only process-global side effect (`ActivityLog` file writes) already takes an injectable `baseDirectory:` that every test uses, so no seam needs adding for isolation.

### Functional Requirements — Toolchain

- **FR-012**: The root `Package.swift` `swift-tools-version` MUST be raised from `5.9` to `6.0`. (The `*-cli/` manifests are deleted, FR-002a, so there is nothing else to raise.)
- **FR-013**: The root `Package.swift` MUST pin Swift 5 language mode for all targets — via the package-level `swiftLanguageModes: [.v5]` argument — so raising the tools-version does not change how any code under test compiles. Per-target `swiftSettings` pins are the fallback only if the package-level form proves insufficient for a target.
- **FR-014**: `swift build -c release` MUST produce all five CLI binaries with no new warnings or errors after the tools-version bump.
- **FR-014a**: The repo-root `.swift-version` file MUST be updated from `5.9` to a version consistent with the new floor (`6.0` or the installed toolchain version), so toolchain-selection tooling does not request a toolchain that cannot build the package.

### Functional Requirements — Parallel safety

- **FR-015**: Running `swift test` five times consecutively on an unchanged checkout MUST produce an identical pass/fail set each time.
- **FR-016**: A test's result MUST NOT depend on whether other tests run before it, or in parallel with it. Suites that cannot yet meet this MUST be explicitly marked to run serially, with a note on why.
- **FR-017**: The migrated suite MUST pass both with parallel execution (the default) and with parallelism disabled.

### Functional Requirements — Documentation

- **FR-018**: `CLAUDE.md`'s testing section (`CLAUDE.md:44`) and its "Active Technologies" bullet (`CLAUDE.md:114`) MUST be rewritten to name Swift Testing as the framework and describe its structure (`@Suite` nesting for grouping, `@Test` per behavior, `#expect` / `#require`), while restating the conventions that carry over unchanged: one behavior per test, natural-sentence descriptions, one test file per source file, edge cases and bad input as first-class tests, new source file and new test file in the same commit.
- **FR-019**: `review.md` (its "Framework: Quick + Nimble" / "Structure: describe → context → it" / "unimplemented behavior gets an `it`" passages) MUST be brought in line with `CLAUDE.md`. `design.md` and `README.md` contain no test-framework reference and need no change.
- **FR-019a**: The constitution (`.specify/memory/constitution.md`) currently has no testing principle. This feature MUST add one — a short principle stating the test framework is Swift Testing, one behavior per test, one test file per source file, natural-sentence descriptions, edge cases and bad input are first-class, source and test ship together — consistent with `CLAUDE.md` and `review.md`.
- **FR-020**: `ARCHITECTURE.md` MUST (a) gain a decision-log entry recording the move, its cause (CLT dropped XCTest; Quick depends on it), and the round-trip history (hand-rolled harness → Quick+Nimble → Swift Testing); (b) rewrite or remove the entries made obsolete by the move — the Objective-C spec-class-collision constraint (`:55`, `:148`), the `AsyncSpec` note (`:98`); and (c) restate the test count and coverage baseline (`:152`, `:166`) against a fresh measurement.

### Functional Requirements — Scope

- **FR-021**: `.github/workflows/` MUST NOT change. CI continues to run `swift build` + `swift test`.
- **FR-024**: Code coverage MUST keep working. `swift test --enable-code-coverage` followed by `xcrun llvm-cov` MUST produce coverage figures equivalent to the pre-migration suite (same tests, same code exercised). Any script, doc, or memory that hardcodes the test-bundle binary path (e.g. `…PackageTests.xctest/Contents/MacOS/…`) MUST be updated to the path the migrated suite produces, or switched to `swift test --show-codecov-path`.
- **FR-022**: Spec 015's `tasks.md`, `plan.md`, `quickstart.md`, and `research.md` MUST be updated where they name `*Spec.swift` files, `QuickSpec`, Nimble, `describe`/`context`/`it`, or "Quick + Nimble", so 015 is implemented Swift-Testing-native. (Its `spec.md`, `contracts/`, and `data-model.md` are already framework-clean.) This is a documentation change to 015's artifacts, done on the `015-argument-shape` branch; it does not implement 015.
- **FR-023**: This feature changes no behavior of any shipping tool. It is a test-infrastructure and toolchain-metadata change only.

### Key Entities

- **Spec file**: A `*Spec.swift` file in a test target. 80 of them, ~6,900 lines total, across `GetClearKitTests` and the five tools' `*LibTests`. Each corresponds to one source file. Migrated in place, keeping its name.
- **Suite**: A `@Suite`-annotated type replacing a `QuickSpec` / `describe` / `context`. Nested to mirror the old grouping.
- **Test**: A `@Test`-annotated function replacing one `it`. Carries a natural-sentence description and one assertion.
- **Root package manifest**: `/Package.swift` — the only manifest SwiftPM reads. Loses its Quick/Nimble dependencies, gains a `6.0` tools-version and a package-level Swift 5 language-mode pin. The five `*-cli/Package.swift` are deleted.
- **Carried-over conventions**: One behavior per test, natural-sentence descriptions, one test file per source file, edge cases first-class, source-and-test in the same commit. Framework-independent; preserved verbatim and written into the constitution (FR-019a).

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a machine with only the Command Line Tools (no Xcode), `swift test` builds and runs the entire suite to completion. Today it fails to build.
- **SC-002**: Zero occurrences of `import Quick` or `import Nimble` in the repository (outside `.build/`). The root `Package.resolved` has no Quick, Nimble, or Cwl* / swift-algorithms / swift-argument-parser / swift-numerics pins. No `*-cli/Package.swift` or `*-cli/Package.resolved` files remain.
- **SC-003**: The count of independent assertions after the migration equals the count before, target by target, with every consolidation individually listed and justified.
- **SC-004**: `swift test` run five times consecutively on an unchanged checkout yields the identical pass/fail set every time.
- **SC-005**: The suite passes both with parallel execution and with `--no-parallel`.
- **SC-006**: `swift build -c release` produces all five binaries with no new warnings after the `swift-tools-version` bump.
- **SC-007**: CI (`swift build` + `swift test`) passes on the branch with no change to `.github/workflows/`.
- **SC-010**: `swift test --enable-code-coverage` + `xcrun llvm-cov` runs clean and reports aggregate line coverage within ~2 points of the last recorded figure (80.66%, `cross-tool-review-2026-04-29.md`), with `RemindersLib` within ~2 of its recorded 91.4% (`ARCHITECTURE.md:166`). Per-target baselines don't exist — coverage can't be measured locally pre-migration — so the comparison is against these recorded aggregates.
- **SC-008**: The only non-test files modified are: the root `Package.swift` / `Package.resolved`, `.swift-version`, `.swiftformat` (only if a rule disable is needed, T005), the deleted `*-cli/` manifests, the documentation files (`CLAUDE.md`, `review.md`, `ARCHITECTURE.md`, constitution), and **exactly one line under `Sources/`** — `Equatable` on `ReminderChangeError` (FR-011).
- **SC-009**: `CLAUDE.md`, `review.md`, `ARCHITECTURE.md`, and the constitution name Swift Testing as the test framework, consistently, and the constitution carries a testing principle it did not have before.
- **SC-011**: Every suite type name is unprefixed (`AddHandlerTests`, not `CalendarAddHandlerSpec`); the naming is uniform across all nine test targets.

---

## Decisions locked (2026-09-01, with Ken)

- **Delete the vestigial `*-cli/Package.swift` + `Package.resolved`.** They are never a build input. `*-cli/Sources/` and `*-cli/Tests/` stay.
- **Bump `.swift-version`** alongside `swift-tools-version`.
- **Add a testing principle to the constitution** — it currently has none.
- **Drop the tool-prefix on suite type names** (option A): `CalendarAddHandlerSpec` → `AddHandlerTests`, uniform bare names across all nine targets. `*Spec.swift` filenames unchanged.
- **Trust-but-verify `ActivityLogSpec` isolation**: migrate it without `.serialized`, then prove it with the five-consecutive-runs and `--no-parallel` checks (SC-004/SC-005). Add `.serialized` only if it actually flakes.
- **One `Sources/` change**: `Equatable` on `ReminderChangeError` (FR-011). Approved — matches the three sibling error types; enables the clean `#expect(throws:)` value form.
- **Package-level `swiftLanguageModes: [.v5]`**, not 23 per-target pins.
- **Pilot on `GetClearKitTests` first** (7 files, includes `ActivityLogSpec`) — it validates the 6.0 bump, the language-mode pin, the XCTest-free build, the `beforeEach`→`init` pattern, and the parallel question in one step.

## Assumptions

- The suite's use of Quick/Nimble is limited to `describe` / `context` / `it`, the matchers `beNil`, `beEmpty`, `contain`, `haveCount`, `beginWith`, `throwError`, Nimble's `==` / `!=` / `<` / `>` operator forms, and `fail()`. The survey (1,073 `it` blocks, full matcher census) found no `equal()`, `beTrue`/`beFalse`, `beCloseTo`, `sharedExamples`, `itBehavesLike`, `waitUntil`, `toEventually`, `afterEach`, `beforeSuite`, or custom matchers. Any usage outside this set discovered during the work is handled explicitly, not dropped.
- Swift 6.3.3 (the installed toolchain) bundles the `Testing` library and SwiftPM's integration for it, which activates at `swift-tools-version: 6.0`.
- Raising `swift-tools-version` to 6.0 with `swiftLanguageModes: [.v5]` does not change compilation of the code under test. If a manifest feature used today is unavailable at 6.0, that is surfaced during the work.
- 28 of the 34 `beforeEach` hooks are one-line `store = Spy…()` resets → suite stored properties. The other 6 (all in `ActivityLogSpec`) already isolate via a per-test `UUID()` temp dir passed as `baseDirectory:` — no production change needed (FR-011).
- The specific-error-value assertions use error types that conform to `Equatable` (`TextError`, `ReminderStoreError`, `CalendarStoreError` already; `ReminderChangeError` via FR-011). The canonical forms for the ~16 error-inspecting closures (returned-error + follow-up `#expect`) and the ~21 `fail()`-in-`guard case` sites (`Issue.record` in the `else` branch) are proposed in research R3 and validated in the pilot.
- CI's GitHub runners have Xcode, so CI passed throughout the local breakage and will pass throughout the migration regardless of ordering.
- Spec 015 is on its own branch, not yet implemented; its FR-022 doc sweep happens on `015-argument-shape`, not this branch.
- SwiftFormat 0.62.1 (pinned) handles Swift Testing macro syntax; the pilot confirms this against the pre-push `swiftformat --lint` gate before the sweep begins.

## Out of Scope

- Rewriting or restructuring any test's logic beyond what the framework change requires. A weak or missing test stays as-is (or is noted), it is not improved here.
- Adding test coverage. Issues #41–45 (Lib-target coverage) are separate.
- Migrating to Swift 6 language mode. Language mode stays v5; only the tools-version moves.
- Changing CI, release, or packaging workflows beyond leaving them untouched.
- Implementing spec 015. Its FR-022 artifact sweep is called out but is done on the `015-argument-shape` branch, separately.
- Adopting Swift Testing features beyond what the migration needs (traits, `.tags`, parameterized tests, exit tests) — those can come later, per-test, as normal work.
- Re-tightening the SwiftLint rules that were loosened for Quick (`static_over_final_class`, `function_body_length` 400). Their rationale goes stale but changing them risks new warnings on production code — a separate cleanup (relates to #196).
- Adding temp-directory cleanup to `ActivityLogSpec` (pre-existing `$TMPDIR` litter). Cheap but not required.
