# Tasks: Migrate Test Suite to Swift Testing

**Input**: Design documents from `/specs/016-swift-testing-migration/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓

## Format: `[ID] [P?] [Story] Description`

- **[P]**: parallelizable (different files, no dependency on an incomplete task)
- **[Story]**: US1 local-run · US2 behavioural-parity · US3 docs · US4 no-flakiness · US5 CI-unchanged
- Paths are relative to the monorepo root

**Tests**: This feature *is* the tests. There are no separate test tasks — each rewrite task's verification is running the rewritten tests.

**Organization**: The spec's user stories are cross-cutting quality attributes, not independent slices. The real unit of independent progress is the **test target** (plan.md's per-target commits). Phases follow that; story labels mark which outcome each task most serves.

**⚠️ PLAN DEVIATION (2026-09-01, commit `7ed56a4`)**: Quick + Nimble were removed from `Package.swift` **entirely** in the toolchain commit, not per-target. Reason: in a Claude session, `swift package resolve` on Quick hits its `Externals/Nimble` submodule → `git-submodule` → the banned `sed`, so keeping `.package(url:)` declared (the plan's R1 strategy) was unworkable. Consequence: **all 80 `*Spec.swift` files stopped compiling at `7ed56a4`**; each Phase-3/4 target restores compilation as it's migrated. T014, T026, and the per-target "remove that target's `.product` entries" steps are **already done** — those tasks reduce to "rewrite the files + verify". `Package.resolved` is already deleted (0 pins).

---

## Phase 1: Setup — baseline

- [x] T001 Confirm `swift build` is green from the repo root (all five binaries link). Record it. Note that `swift test` currently fails to build (`XCTest/XCTest.h` not found) — that is the starting condition, not a regression.
- [x] T002 Capture the parity baseline: per test target, count `it(` occurrences and record them in a scratch table for later reconciliation (SC-003). Totals expected: GetClearKitTests 212, ContactKitTests 26, AppleContactKitTests 14, AppleEventKitSupportTests 11, CalendarLibTests 199, ContactsLibTests 60, MailLibTests 154, RemindersLibTests 327, TextLibTests 70 — **1,073** total. Coverage can't be captured locally now (`swift test` is broken); record the last aggregate figures — 1,032 tests / 80.66% line (`cross-tool-review-2026-04-29.md`), RemindersLib 91.4% (`ARCHITECTURE.md:166`) — as the SC-010 reference.

---

## Phase 2: Foundational — toolchain (blocks everything)

**⚠️ CRITICAL**: `swift-tools-version: 6.0` is the prerequisite for Swift Testing's SwiftPM integration. No file can be migrated until the manifest moves.

- [x] T003 Update `Package.swift`: line 1 `// swift-tools-version: 5.9` → `// swift-tools-version: 6.0`; add `swiftLanguageModes: [.v5]` as an argument to `Package(...)` (per research.md R5 — package-level, not per-target). Do **not** yet touch `dependencies` or the testTarget dependency lists. `swift build` — green, no new warnings.
- [x] T004 Update `.swift-version`: `5.9` → `6.0` (research.md R4).
- [x] T005 Run `swiftformat --lint .` over the whole tree with the new `.swift-version` in place. Verified clean at `.swift-version` 6.0 — no new findings. The `--swift-version 6.0` context surfaced 2 pre-existing warnings (`SpyContactStore` Sendable, `main.swift` `usage()` unused), unchanged from 5.9 (confirmed by forced recompile). (research.md R2)
- [x] T005a **SwiftLint fix (FR-025).** SwiftLint was crash-looping on this CLT-only machine and the pre-push hook silently passed the crash. Created `scripts/lint` (sets `DYLD_FRAMEWORK_PATH=$(xcode-select -p)/usr/lib`, fails on crash, allows warnings, blocks errors + format violations); `.githooks/pre-push` now `exec`s it. Disabled `.swiftlint.yml` `opening_brace` (contradicts SwiftFormat `wrapMultilineStatementBraces`) and set `trailing_whitespace: ignores_empty_lines: true` (matches `.swiftformat`) — 104 → 71 warnings, no code change. Filed #198 for the 71.
- [x] T006 Determine the local-verification capability: on this CLT-only machine, after the pilot target is migrated (Phase 3), does `swift build --build-tests --target GetClearKitTests` compile in isolation (only `GetClearKit` + `GetClearKitTests` + `Testing`, not the Quick-importing sibling test targets)? Record the answer. If **yes**, each Phase 4 target is locally verifiable as it lands. If **no**, per-target verification is CI-only until Phase 5 removes Quick entirely (T026), and the first full local `swift test` is at T035. (This task is a check, done as part of T015.)

**Checkpoint**: `swift build` green at tools-version 6.0 with Swift 5 language mode; lint/format clean tree-wide.

---

## Phase 3: Pilot — `GetClearKitTests` (US1, US2) 🎯 MVP GATE

**Goal**: the smallest target (7 files, 212 `it`s, includes `ActivityLogSpec`) fully on Swift Testing, Quick/Nimble gone from *its* manifest entry, and — if T006 says it's possible — running green on this CLT-only machine. This one commit validates the toolchain bump, the language-mode pin, the XCTest-free build path, the `beforeEach`→`init` pattern, the three fiddly-bucket forms, and the ActivityLog parallel question.

**Independent Test**: `swift build --build-tests --target GetClearKitTests` compiles with no XCTest; if runnable, `swift test --filter GetClearKitTests` is green, five consecutive runs identical, `--no-parallel` also green; `@Test` count = 212 (± listed consolidations); `swiftformat --lint Tests/GetClearKitTests/` clean.

- [x] T007 [US2] Rewrite `Tests/GetClearKitTests/GetClearKitSpec.swift` → `@Suite`/`@Test`/`#expect` per `quickstart.md` and `contracts/migration-rules.md`. Type `GetClearKitTests` (was `GetClearKitSpec`). This file has the `parseArgs` `guard case … else { fail() }` sites (research.md R3 bucket 3 → `Issue.record` / Bool-hoist).
- [x] T008 [P] [US2] Rewrite `Tests/GetClearKitTests/RangeParserSpec.swift` (the `quickstart.md` worked example).
- [x] T009 [P] [US2] Rewrite `Tests/GetClearKitTests/DateParserSpec.swift` (has `expect(diff) <= 7` → `#expect(diff <= 7)`).
- [x] T010 [P] [US2] Rewrite `Tests/GetClearKitTests/ValueChangeSpec.swift` (has `expect(x) != y` on enum values).
- [x] T011 [P] [US2] Rewrite `Tests/GetClearKitTests/ToolIdentitySpec.swift`.
- [x] T012 [P] [US2] Rewrite `Tests/GetClearKitTests/CalendarDotSpec.swift`.
- [x] T013 [US2] [US4] Rewrite `Tests/GetClearKitTests/ActivityLogSpec.swift` — the only non-trivial file. Its 6 `beforeEach` (contexts: file creation, entry content, nil container, appending, filtering by tool, malformed lines) + the 3 inline temp-dir tests in `context("FR-018 recency rule")`. Each nested `@Suite` gets a per-instance `let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("gc-test-\(UUID().uuidString)")` and an `init() throws` doing the writes. Normalize the `context("malformed lines")` closure-local `let` to the same shape. Do **not** add `@Suite(.serialized)` yet.
- [x] T014 [US1] Update `Package.swift`: remove `.product(name: "Quick", …)` and `.product(name: "Nimble", …)` from the **`GetClearKitTests`** testTarget only (lines ~37-38). Leave the `.package(url:)` declarations and the other 8 testTargets' product entries untouched (research.md R1).
- [x] T015 [US1] [US4] Verify the pilot: `swift build --build-tests --target GetClearKitTests` (answers T006). If it compiles standalone: `swift test --filter GetClearKitTests` ×5 — identical every run — then `--no-parallel` — green. If `ActivityLogSpec` flakes, add `@Suite(.serialized)` to it and note why. `swiftformat --lint Tests/GetClearKitTests/` clean. `grep -c '@Test' Tests/GetClearKitTests/*.swift` = 212 (or list each consolidation). If it does **not** compile standalone, verify via `swift build` + push to let CI run it, and record that Phase 4 is CI-verified until T026/T035.
- [x] T016 Write `specs/016-swift-testing-migration/migration-notes.md` — start it here: the chosen canonical form for each of the three fiddly buckets (with a real before/after example from the pilot), the T005 lint findings, the T006 answer, and whether `ActivityLogSpec` needed `.serialized`.

**Checkpoint**: pilot commit. **Stop here for Ken to run it on his machine and confirm before Phase 4.**

---

## Phase 4: Remaining 8 targets (US1, US2) — one commit each, smallest first

Each target: rewrite every `*Spec.swift` (type names lose the tool prefix — `CalendarAddHandlerSpec` → `AddHandlerTests`); remove that target's two `.product` entries from `Package.swift`; verify (`swift build --build-tests --target <T>` at minimum, `swift test --filter <T>` ×5 + `--no-parallel` if T006 was yes); `swiftformat --lint` the target dir; reconcile the `@Test` count; **diff-review every rewritten file against its original for assertion faithfulness — same input, same expected value, same matcher semantics (US2 Independent Test)**; append any new consolidations / decisions to `migration-notes.md`.

Per the manifest-strategy deviation, "Update the manifest" was already done in `7ed56a4` — each task reduces to rewrite + verify. Verification ran as: strip the other 8 `testTarget`s from `Package.swift`, `./scripts/test --filter <T>`, restore (D3).

- [x] T017 [US2] `Tests/AppleEventKitSupportTests/` — `CGColorHexSpec`, 11 `it` → **11 `@Test`** ✓. Commit.
- [x] T018 [US2] `Tests/AppleContactKitTests/` — `ToContactSpec`, 14 → **14** ✓. Commit.
- [x] T019 [US2] `Tests/ContactKitTests/` — 3 files, 26 → **26** ✓ (`SpyContactStoreSpec` `AsyncSpec` → `@Suite`). Commit.
- [x] T020 [US2] `text-cli/Tests/TextLibTests/` — 7 files, 70 → **70** ✓ (`SpyMessageSender` file-private kept; `throwError(TextError.case)` → `#expect(throws: TextError.case)`; `expect(try! f())` → `@Test throws`). Commit.
- [x] T021 [US2] `mail-cli/Tests/MailLibTests/` — 11 files, 154 → **154** ✓ (no bucket-2 after all; `.notTo(throwError())` → `#expect(throws: Never.self)`). Commit.
- [x] T022 [US2] `contacts-cli/Tests/ContactsLibTests/` — 12 files, 60 → **60** ✓. Commit.
- [x] T023 [US2] `calendar-cli/Tests/CalendarLibTests/` — 19 files, 199 → **199** ✓ (Calendar-prefixed types → unprefixed; `CalendarStoreSpec` ambiguous inspecting closure → returned-error + `guard case …? `; Show/RemoveHandlerSpec `CalendarHandlerError.description` bucket-2). Commit.
- [x] T024 [US2] `reminders-cli/Tests/RemindersLibTests/` — 19 files, 327 → **327** ✓ (16 `ReminderHandlerError.message` bucket-2; `OptionsParsingSpec` 3-level nesting preserved; `MockStore` stays `private` so its suite `let store` is `private let`; `ChangeCommandSpec` 6 `if case … else { fail() }` → `guard case`/`Issue.record`). Commit (with T025).
- [x] T025 [US2] `reminders-cli/Sources/RemindersLib/ReminderChangeParsing.swift:24`: `ReminderChangeError: Error` → `Error, Equatable`. Shipped in the T024 commit. Only `Sources/` change. `swift build` green, no behaviour change. Recorded in `migration-notes.md`.

**Checkpoint**: all 9 targets on Swift Testing. Full `./scripts/test` → **1073 tests in 384 suites passed** on the CLT-only machine.

---

## Phase 5: Remove Quick/Nimble; delete vestigial manifests (US1)

- [x] T026 [US1] Already done in `7ed56a4` — Quick/Nimble + the `dependencies:` key removed from `Package.swift` entirely (the manifest-strategy deviation).
- [x] T027 [US1] Already done in `7ed56a4` — `Package.resolved` had 0 pins and SwiftPM deleted it; `.build/checkouts/` no longer holds the 7 dirs.
- [x] T028 [US1] `git rm`'d `{reminders,calendar,contacts,mail,text}-cli/Package.swift` + `Package.resolved` (10 files).
- [x] T029 [P] [US1] `git rm -r`'d `{reminders,calendar,contacts,mail,text}-cli/.github/` (10 dead workflow files).
- [x] T030 [US1] `grep -rn "import Quick\|import Nimble" --include="*.swift" .` (outside `.build/`) → **0**. `grep -rn "QuickSpec\|AsyncSpec\|\.to(equal\|describe(\|context(\|beforeEach" …` → **0**.

**Checkpoint**: Quick and Nimble are entirely gone from the repo.

---

## Phase 6: Documentation + constitution (US3)

- [x] T031 [P] [US3] `CLAUDE.md` testing paragraph + Active Technologies bullet (`Swift 6.0 (swift-tools-version: 6.0, language mode v5) + Swift Testing`) rewritten per `contracts/doc-text.md`.
- [x] T032 [P] [US3] `review.md` "Framework" + "Structure" bullets rewritten per `contracts/doc-text.md`. The `swift test` / coverage checklist items unchanged.
- [x] T033 [P] [US3] New "Tests are Swift Testing, and they are code" principle added to `specs/constitution.md` (the `.specify/memory/constitution.md` symlink target), after "GetClearKit first".
- [x] T034 [US3] `ARCHITECTURE.md`: decision-log entry added (2026-09-01, round-trip history + CLT-dropped-XCTest cause + CLT tooling note); the ObjC-collision "spec class naming" and `AsyncSpec` notes rewritten. `:152`/`:166` left for T037. `.swiftlint.yml:27` comment was already corrected in T005a ("Quick is gone (spec 016)").

---

## Phase 7: Validation (US1, US4, US5, SC coverage)

- [x] T035 [US1] [US4] `./scripts/test` from the repo root — **1073 tests in 384 suites passed** on this CLT-only machine (SC-001). Five consecutive runs, identical every time (SC-004). `--no-parallel` — same 1073/1073 (SC-005). No flakes; no `.serialized` needed anywhere.
- [x] T036 [US1] `swift build -c release` — all five binaries link; the only 2 warnings are the pre-existing baseline ones (`SpyContactStore` Sendable, `main.swift` `usage()` unused), zero new (SC-006).
- [x] T037 [US4] Coverage (`xcrun llvm-cov report` on `get-clearPackageTests.xctest`, `-ignore-filename-regex="(\.build|Tests)"`): aggregate **81.6% line** (was 80.66%; +1) — within tolerance. **RemindersLib 92.6% line** (was 91.4%; +1.2) — within tolerance (SC-010). `ARCHITECTURE.md` `:164`/`:178` restated with the fresh numbers.
- [x] T038 [US2] Parity table in `migration-notes.md` complete: 1,073 `it` → **1,073 `@Test`** across all 9 targets, **zero consolidations** (SC-003).
- [x] T039 [US5] `git diff main --stat -- .github/workflows/` → empty (SC-007). `git diff main --stat -- '**/Sources/**'` → only `ReminderChangeParsing.swift` (SC-008). No `*Spec`-typed suites; all suite types unprefixed (SC-011).
- [ ] T040 Push the branch; `.githooks/pre-push` (`./scripts/lint`) passes. Open the PR; CI (`swift build` + `swift test` on `macos-latest`) is green.

---

## Phase 8: Follow-ups (not on this branch)

- [ ] T041 On the `015-argument-shape` branch (separate): doc-only commit updating `specs/015-argument-shape/{tasks.md,plan.md,quickstart.md,research.md}` per FR-022 — `*Spec.swift`/`QuickSpec`/`Nimble`/`describe`/`context`/`it` → Swift Testing vocabulary; the `quickstart.md:85-93` Quick code block → `@Suite`/`@Test`/`#expect(throws:)`. Does not implement 015.
- [ ] T042 Flag to Ken (out of repo): `~/.claude/projects/-Users-ken-dev-get-clear/memory/project_coverage_tooling.md` hardcodes `.build/…/get-clearPackageTests.xctest/Contents/MacOS/…` — update to the `swift test --show-codecov-path` + `swift build --show-bin-path` recipe (FR-024). Cross-machine via the dotfiles symlink.
- [ ] T043 (Deferred, relates to #196) Re-tighten the SwiftLint rules loosened for Quick — `static_over_final_class` (`.swiftlint.yml:27`), `function_body_length` error 400 (`:79`). Check for new `Sources/` warnings first. Not part of this migration.

---

## Dependencies

```
T001,T002 (setup)
  └─ T003 ─ T004 ─ T005            (toolchain — Phase 2)
      └─ T007 … T013 [P after T007] (pilot rewrites — Phase 3)
          └─ T014 (manifest) ─ T015 (verify, answers T006) ─ T016 (notes)
              │  ◄── STOP: Ken runs the pilot ──►
              └─ T017 ─ T018 ─ T019 ─ T020 ─ T021 ─ T022 ─ T023 ─ (T024 + T025)   (Phase 4, sequential — each edits Package.swift)
                  └─ T026 ─ T027 ─ T028 ─ T029 [P] ─ T030      (Phase 5)
                      └─ T031 [P] ─ T032 [P] ─ T033 [P] ─ T034  (Phase 6 docs)
                          └─ T035 ─ T036 ─ T037 ─ T038 ─ T039 ─ T040   (Phase 7)
                              └─ T041, T042, T043   (Phase 8 — separate)
```

Phase 4 tasks are **sequential** (each touches `Package.swift`), not parallel — but the file rewrites *within* a Phase-4 task are independent of each other.

## Implementation Strategy

- **MVP = Phases 1–3.** The toolchain moves, the pilot target is fully migrated and (if T006 allows) runs green on a machine with no Xcode. This is the proof the whole feature rests on. **Hand back to Ken here.**
- **Phase 4** is repetition of the pilot pattern across 8 targets. Each is an independent commit; a failure in one doesn't block the others' review.
- **Phase 5** is the payoff — Quick/Nimble gone, `swift test` works locally.
- **Phases 6–7** are docs and proof against the 11 success criteria.
- The one `Sources/` change (T025) is the only place this migration touches shipping code.
