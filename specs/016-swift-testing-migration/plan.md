# Implementation Plan: Migrate Test Suite to Swift Testing

**Branch**: `016-swift-testing-migration` | **Date**: 2026-09-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/016-swift-testing-migration/spec.md`

## Summary

Replace Quick + Nimble with Swift Testing across all 80 `*Spec.swift` files (1,073 `it` blocks, 9 test targets), so `swift test` builds and runs on the Command Line Tools with no Xcode. Quick's `QuickSpec` subclasses `XCTestCase`, dragging in XCTest — which recent CLT versions no longer ship. Swift Testing has no XCTest dependency.

The work is mechanical: `describe`/`context` → nested `@Suite`; `it` → `@Test`; the Nimble matcher census reduces to ~15 regular `#expect` forms plus three fiddly buckets (~47 sites) that each get one canonical form decided in the pilot. Root `Package.swift` moves to `swift-tools-version: 6.0` with a package-level `swiftLanguageModes: [.v5]` pin; the five vestigial `*-cli/Package.swift` are deleted. One production line changes: `Equatable` conformance added to `ReminderChangeError` to match its three sibling error types. Docs (`CLAUDE.md`, `review.md`, `ARCHITECTURE.md`) are rewritten and the constitution gains its first testing principle.

Delivered pilot-first (`GetClearKitTests`, 7 files) to validate the toolchain bump, the language-mode pin, the XCTest-free build, the `beforeEach`→`init` pattern, and parallel safety in one step; then one commit per remaining target.

## Technical Context

**Language/Version**: Swift 6.3.3 (installed, Command Line Tools only — no Xcode); `swift-tools-version` 5.9 → 6.0; language mode stays Swift 5
**Primary Dependencies**: removing Quick 7.6.2 + Nimble 13.8.0 and their 5 transitive pins; adding nothing (`Testing` ships in the toolchain)
**Storage**: N/A
**Testing**: Swift Testing (`import Testing`, `@Suite` / `@Test` / `#expect` / `#require`), run via `swift test`
**Target Platform**: macOS 14+; builds and tests on CLT-only (that is the point) and on CI's Xcode-equipped `macos-latest`
**Project Type**: CLI suite (monorepo) — single root SwiftPM package, 9 test targets
**Performance Goals**: N/A — parity of results, not speed (parallel execution is a free side benefit)
**Constraints**: no change under `Sources/` except one `Equatable` conformance; `.githooks/pre-push` runs `swiftformat --lint .` over the rewritten files; every increment keeps `swift build` green
**Scale/Scope**: 80 files, 1,073 `it` blocks, 34 `beforeEach`, 32 async files, ~47 non-regular assertion sites; 1 manifest edited, 5 deleted; 4 docs

## Constitution Check

*GATE: Must pass before Phase 0. Re-checked after Phase 1 design — still passes.*

The constitution governs tool runtime behavior. This feature touches only tests and toolchain metadata, so most principles are N/A. Relevant reads:

| Rule | Status | Notes |
|------|--------|-------|
| Tools handle what they can | ✓ N/A | No tool behavior changes |
| No flags | ✓ N/A | No CLI surface touched |
| No silent failures | ✓ ALIGNED | FR-004: every assertion is preserved; a migration that silently dropped a `#expect` would violate the spirit. SC-003 enforces the count. |
| Stdout / stderr split | ✓ N/A | |
| Add and remove ship together | ✓ N/A | |
| Read-only commands never write | ✓ N/A | |
| The vocabulary is fixed | ✓ N/A | |
| Setup is idempotent | ✓ N/A | |
| Internal commands absent from usage() | ✓ N/A | |
| Phoning home requires consent | ✓ N/A | |
| Color has exactly three levels | ✓ N/A | |
| GetClearKit first | ✓ N/A | No shared logic added; `Equatable` on `ReminderChangeError` stays local to `RemindersLib` beside its siblings |
| Timestamps from the system clock | ✓ N/A | |

**This feature adds a principle to the constitution** (FR-019a) — a testing-discipline entry. The constitution has none today; this fills a gap rather than conflicting with anything. Drafted in `contracts/constitution-testing-principle.md`.

**No violations. Complexity Tracking omitted.**

## Project Structure

### Documentation (this feature)

```text
specs/016-swift-testing-migration/
├── plan.md              # This file
├── spec.md
├── survey.md            # Pre-plan survey (two parallel passes)
├── research.md          # Phase 0 — decisions on the fiddly translation buckets, tooling
├── data-model.md        # Phase 1 — the construct-mapping tables (Quick → Swift Testing)
├── contracts/           # translation-rules.md, doc-text.md, constitution-testing-principle.md
├── quickstart.md        # Phase 1 — migrate-one-file recipe
└── tasks.md             # Phase 2 (/speckit.tasks — not created here)
```

### Source Code

Nothing new is created. Changes, by kind:

```text
Package.swift                      UPDATE — swift-tools-version 5.9→6.0;
                                            swiftLanguageModes: [.v5] on Package(...);
                                            remove Quick + Nimble from dependencies and
                                            from all 9 testTarget dependency lists
Package.resolved                   REGEN  — schema v2→v3; 0 pins after removal
.swift-version                     UPDATE — 5.9 → 6.0
reminders-cli/Package.swift        DELETE  ┐
calendar-cli/Package.swift         DELETE  │  vestigial — never a build input
contacts-cli/Package.swift         DELETE  │  (FR-002a). Their Package.resolved,
mail-cli/Package.swift             DELETE  │  stale .build/, and orphaned .github/
text-cli/Package.swift             DELETE  ┘  workflows go with them.
{reminders,calendar,contacts,mail,text}-cli/Package.resolved   DELETE

reminders-cli/Sources/RemindersLib/ReminderChangeParsing.swift  UPDATE —
                                            `enum ReminderChangeError: Error, Equatable`
                                            (one word; matches ReminderStoreError /
                                            CalendarStoreError / TextError). The sole
                                            Sources/ change — FR-011's listed exception.

Tests/GetClearKitTests/*Spec.swift            REWRITE  (7 files — pilot)
Tests/ContactKitTests/*Spec.swift             REWRITE  (3)
Tests/AppleContactKitTests/*Spec.swift        REWRITE  (1)
Tests/AppleEventKitSupportTests/*Spec.swift   REWRITE  (1)
calendar-cli/Tests/CalendarLibTests/*Spec.swift    REWRITE  (19)
contacts-cli/Tests/ContactsLibTests/*Spec.swift    REWRITE  (12)
mail-cli/Tests/MailLibTests/*Spec.swift            REWRITE  (11)
reminders-cli/Tests/RemindersLibTests/*Spec.swift  REWRITE  (19)
text-cli/Tests/TextLibTests/*Spec.swift            REWRITE  (7)
      — filenames unchanged; suite type names lose the tool prefix (FR-010, option A)

Tests/ContactTestSupport/{SpyContactStore,Fixtures}.swift   KEEP — public test-support
      target, no Quick import; unaffected except possible Sendable review under v5 (none)
reminders-cli/Tests/RemindersLibTests/Fixtures.swift        KEEP
calendar-cli/Tests/CalendarLibTests/Fixtures.swift          KEEP
mail-cli/Tests/MailLibTests/MailTestSupport.swift           KEEP

CLAUDE.md                          UPDATE — :44 testing section, :114 tech bullet (FR-018)
review.md                          UPDATE — :92/:94/:96 framework prose (FR-019)
ARCHITECTURE.md                    UPDATE — new decision-log entry; rewrite :55/:98/:148;
                                            restate :152/:166 counts (FR-020)
.specify/memory/constitution.md    UPDATE — add testing principle (FR-019a)

.github/workflows/                 NO CHANGE (FR-021)
.swiftlint.yml                     NO CHANGE (Tests/ already excluded; rule cleanup out of scope)
.swiftformat                       NO CHANGE unless the pilot lint check fails
```

**Structure Decision**: single root SwiftPM package (existing). No new targets, no new files. The migration is edits + deletions + doc rewrites.

## Implementation Sequence

Dependency order: toolchain → pilot target → remaining targets → dependency removal → docs. Each target-level step is independently verifiable with `swift test --filter <Target>` and keeps `swift build` green.

### Step 1 — Toolchain + pilot (`GetClearKitTests`)

The one step that de-risks everything. In a single commit:

1. `Package.swift`: `// swift-tools-version: 6.0`; add `swiftLanguageModes: [.v5]` to `Package(...)`; remove the two `.package(url:)` lines; remove the `Quick` / `Nimble` `.product(...)` entries from **all 9** testTargets (they no longer resolve, so a partial removal breaks the manifest).
2. `.swift-version` → `6.0`.
3. Delete Quick/Nimble usage from `GetClearKitTests` by rewriting its 7 files to Swift Testing (`GetClearKitSpec`, `RangeParserSpec`, `DateParserSpec`, `ValueChangeSpec`, `ToolIdentitySpec`, `CalendarDotSpec`, `ActivityLogSpec`). Every other test target still imports Quick and **will not compile** — so this commit's verification is scoped:
   - `swift build` (non-test targets) — green
   - `swift build --target GetClearKitTests` won't work while sibling test targets are broken; instead verify by temporarily commenting the other testTargets OR (cleaner) accept that `swift test` is red until Step 2 completes and rely on `swift build` + a local scratch check. **Decision in research.md: rewrite GetClearKitTests AND stub the other 8 test targets' files in the same commit** (see Step 1a) so `swift test --filter GetClearKitTests` runs immediately.
4. `swiftformat --lint Tests/GetClearKitTests/` with the pinned 0.62.1 — must be clean (the pre-push gate). If it mangles `#expect { }`, resolve per research.md before proceeding.
5. Run `swift test --filter GetClearKitTests` five times + once `--no-parallel`. `ActivityLogSpec` must be identical every run. If it flakes, add `@Suite(.serialized)` to that suite only.

**Checkpoint**: `GetClearKitTests` green on CLT-only, five identical runs, SwiftFormat clean.

### Step 1a — the "compiles throughout" decision

Removing Quick/Nimble from the manifest in Step 1 breaks compilation of the 73 not-yet-migrated files. Two ways to keep the tree buildable:

- **A — big-bang the manifest, migrate target-by-target, tolerate red `swift test` between steps.** `swift build` stays green; `swift test` is red until the last target lands. Simple, but no incremental test signal.
- **B — migrate all 80 files first (Quick still declared), then remove Quick/Nimble in one final commit.** Keeps `swift test` runnable in CI (which has XCTest) throughout, but gives zero *local* signal until the very end — the opposite of what we want on a CLT-only machine.
- **C (chosen) — per-target: migrate a target's files AND drop that target's Quick/Nimble `.product` entries in the same commit.** The manifest keeps `.package(url: Quick/Nimble)` until the final target, so not-yet-migrated targets still resolve. After each commit, `swift test --filter <MigratedTarget>` runs on CLT-only. Final commit removes the two `.package` lines and the pins.

Research.md records C and the exact manifest sequence.

### Step 2 — Remaining 8 targets, one commit each

Order (smallest first, shared-support dependencies respected):
`AppleEventKitSupportTests` (1) → `AppleContactKitTests` (1) → `ContactKitTests` (3) → `TextLibTests` (7) → `MailLibTests` (11) → `ContactsLibTests` (12) → `CalendarLibTests` (19) → `RemindersLibTests` (19).

`RemindersLibTests` last — it has the most files, the `ReminderChangeError` Equatable change, the deepest-nested file (`OptionsParsingSpec`), and the two-doubles wrinkle (`SpyStore` + `MockStore`).

Each commit: rewrite the target's `*Spec.swift`, drop its Quick/Nimble `.product` entries, `swift test --filter <Target>` green, `swiftformat --lint` clean.

### Step 3 — Remove Quick/Nimble entirely

`Package.swift`: delete the two `.package(url:)` lines. `swift package resolve` → `Package.resolved` regenerates with zero pins. `.build/checkouts/` empties of the 7 dirs. `grep -r "import Quick\|import Nimble"` → zero. Full `swift test` green on CLT-only, five runs, `--no-parallel`.

### Step 4 — Delete vestigial manifests

`git rm` the five `*-cli/Package.swift` + `*-cli/Package.resolved`. Optionally `git rm -r` the stale `*-cli/.build/` and `*-cli/.github/`. `swift build` + `swift test` unaffected (they never referenced these).

### Step 5 — Docs + constitution

- `CLAUDE.md:44` + `:114`, `review.md:92/:94/:96` — rewrite per `contracts/doc-text.md`.
- `.specify/memory/constitution.md` — add the principle from `contracts/constitution-testing-principle.md`.
- `ARCHITECTURE.md` — decision-log entry (round-trip history + CLT cause); rewrite `:55`, `:98`, `:148`; re-measure and restate `:152` (`swift test` count) and `:166` (coverage).
- Update this session's coverage-tooling memory note is **out of repo** — flag to Ken separately (FR-024 mentions it; it is `~/.claude/…/project_coverage_tooling.md`, not a repo file).

### Step 6 — Validation

- `swift build -c release` — five binaries, no new warnings (SC-006).
- `swift test` — full suite green on CLT-only (SC-001); five identical runs (SC-004); `--no-parallel` also green (SC-005).
- `swift test --enable-code-coverage` + `xcrun llvm-cov report` via `swift test --show-codecov-path` — figures within ~2 points of baseline per target (SC-010).
- Assertion-count reconciliation table: `it` count before vs `@Test` count after, per target, consolidations listed (SC-003).
- `grep` sweeps: no `import Quick`/`import Nimble`; no `*-cli/Package.swift`; no `CalendarAddHandlerSpec`-style prefixed type (SC-002, SC-011).
- `.github/workflows/` diff clean (SC-007); nothing under `Sources/` except `ReminderChangeError` (SC-008).
- Push → `.githooks/pre-push` (`swiftlint`, `swiftformat --lint`) passes.

### Step 7 — Spec 015 (separate branch)

On `015-argument-shape`: doc-only commit updating `tasks.md`, `plan.md`, `quickstart.md`, `research.md` per FR-022. Not part of this branch.

## Complexity Tracking

No constitution violations. The one production change (`Equatable` on `ReminderChangeError`) is FR-011's explicitly-permitted exception and is recorded in the migration notes.
