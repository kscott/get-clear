# Migration Notes — Swift Testing (spec 016)

Running record of decisions, deviations, and per-target consolidations.

---

## Plan deviations

### D1 — Quick/Nimble removed from the manifest up front (commit `7ed56a4`)

The plan (research R1) kept `.package(url: Quick/Nimble)` declared and removed each target's `.product` refs as it migrated, so unmigrated targets kept compiling. **Unworkable in a Claude session**: `swift package resolve` on Quick runs `git submodule update` for its `Externals/Nimble` submodule, which calls `sed`, which Ken's shim blocks whenever `CLAUDECODE` is set. So Quick could never re-resolve.

Instead: Quick + Nimble removed entirely (dependencies + all 9 testTargets) in the toolchain commit. `Package.resolved` → 0 pins → SwiftPM deleted it. Consequence: all 80 `*Spec.swift` stopped compiling at `7ed56a4`; each Phase-3/4 target restores compilation as it's migrated. T014/T026 are effectively already done.

`swift build` (6 binaries) stayed green. `swift test` was already broken locally (XCTest); CI (`push` to `main` only) is not triggered by this branch.

---

## Toolchain (T003–T005)

- `swift-tools-version` 5.9 → 6.0; `swiftLanguageModes: [.v5]` on `Package(...)` (package-level — must come *after* `targets:` in the arg order, else `error: argument 'products' must precede argument 'swiftLanguageModes'`).
- `.swift-version` 5.9 → 6.0.
- SwiftFormat 0.62.1 verified clean tree-wide at `.swift-version` 6.0.
- **Warnings.** At T005 two were noted from the `--swift-version 6.0` context. Once all test targets compile (they didn't pre-016), a full clean `./scripts/test` build surfaced **3**:
  - `Tests/ContactTestSupport/SpyContactStore.swift` — `contacts` (and siblings) mutable `var` in a `Sendable` conformer (`ContactStore: Sendable`). **Fixed** — `@unchecked Sendable` + a comment ("Swift Testing gives every `@Test` its own suite instance and thus its own spy — no spy is shared across concurrent tests").
  - `mail-cli/Tests/MailLibTests/MailTestSupport.swift` — `SpyMailClient` mutable `var`s in a `Sendable` conformer (`MailClient: Sendable`); `MailTestSupport.swift` was byte-identical to `main` — the warning was always latent, invisible only because `MailLibTests` never compiled. **Fixed** the same way.
  - `Sources/GetClear/main.swift:18` — `usage()` result unused `[#no-usage]`. **Left** (FR-011 — `Sources/`, out of scope). This is now the only warning on a full test build.
  - `SpyStore` / `SpyCalendarStore` / `SpyMessageSender` / `MockStore` conform to **non-`Sendable`** protocols → no warning, no annotation needed.

---

## SwiftLint (T005a / FR-025)

- SwiftLint was crash-looping on this CLT-only machine: SourceKitten's `dlopen` for `sourcekitdInProc.framework` doesn't try `$(xcode-select -p)/usr/lib`, where the CLT keeps it.
- The pre-push hook greps SwiftLint output for `: error:`; the crash prints `Fatal error:`, so the hook **silently passed every crash** — SwiftLint has not actually linted on any push for weeks.
- Fix: `scripts/lint` (new) — exports `DYLD_FRAMEWORK_PATH`, detects a crash and exits 1, allows warnings, blocks `: error:` and SwiftFormat violations. `.githooks/pre-push` reduced to `exec scripts/lint`.
- `.swiftlint.yml`: `opening_brace` disabled (contradicts SwiftFormat `wrapMultilineStatementBraces`, which `.swiftformat` keeps ON); `trailing_whitespace: ignores_empty_lines: true` (matches `.swiftformat --trimwhitespace nonblank-lines`). 104 → **71** warnings, zero code change — verified `swift run reminders-bin help` md5-identical.
- The 71 remaining (`force_unwrapping` ×46, `force_try` ×7, `force_cast` ×3, complexity ×5, length ×5, misc ×5) → **issue #198**, not this feature.

---

## The pilot — GetClearKitTests (commit pending)

**Result: `Test run with 212 tests in 58 suites passed` on this CLT-only machine.** Exact parity with the 212 `it()` baseline — zero consolidations. Five consecutive runs identical; `--no-parallel` also 212/212. `ActivityLogSpec` did **not** flake under parallel execution — the per-instance `UUID()` temp dirs hold — so **no `@Suite(.serialized)` needed** (trust-but-verify: verified). SwiftFormat clean (`0/7`).

### D2 — Swift Testing needs framework + rpath flags on the CLT

SwiftPM 6.x on the Command Line Tools does not wire up the toolchain's bundled `Testing.framework`:
1. **Compile:** it passes `-I <…/Library/Developer/Frameworks>` where it needs `-F` → `error: no such module 'Testing'`.
2. **Link/run:** the test binary references `@rpath/Testing.framework/…` and `@rpath/lib_TestingInterop.dylib` (the latter in a *different* dir, `…/Library/Developer/usr/lib/`), and neither rpath is baked in. `DYLD_FRAMEWORK_PATH` can't help — SIP strips `DYLD_*` from the Apple-signed `swiftpm-testing-helper`.

**Fix: `scripts/test`** (new) — `swift test` with `-Xswiftc -F -Xswiftc <frameworks>` plus `-Xlinker -rpath` for both `<frameworks>` and `<…/usr/lib>`. Devs, and any future test hook, call `scripts/test`. Harmless on CI (full Xcode resolves `Testing` natively) — `.github/workflows/ci.yml` stays `swift test`, unchanged.

### D3 — `swift test --filter` still compiles every test target

Confirmed: `swift test --filter GetClearKitTests` compiles all 9 test targets, so it fails on the 8 not-yet-migrated ones (`import Quick`). **`swift build --target <TestTarget>` DOES compile one in isolation** (with `-Xswiftc -F …`), so each Phase-4 target's *compilation* is locally checkable as it lands — but *running* it needs the full migration done (or the sibling test targets temporarily commented out, which is how the pilot was executed and stability-checked).

## Canonical forms for the fiddly buckets (research R3 — validated in the pilot)

- **Bucket 3 — `fail()` in `guard case`**: `Issue.record("…")` in the `else` branch, then `return` (or `continue` in a loop). Used in `GetClearKitSpec` (`parseArgs`) and `DateParserSpec` (weekday loop).
- **Bucket 2 — error-inspecting closure**: `let err = #expect(throws: T.self) { … }; #expect(err?.message.contains(…) == true)`. Exercised heavily in RemindersLibTests (16 `ReminderHandlerError.message` sites across the handler specs) plus Calendar's `CalendarHandlerError.description`. Where the closure did `if case … else { fail() }` (ReminderStoreSpec, CalendarStoreSpec), the follow-up is `guard case let .x(v)? = err else { Issue.record(…); return }` then `#expect` on `v` — the `?` pattern because `#expect(throws:)` returns `T?`.
- **File-private double stored on a suite struct**: `MockStore` (ReminderStoreSpec) is `private`, so the `let store = MockStore()` on each nested `@Suite` struct must be `private let` (a non-private struct property can't expose a private type).
- **Bucket 1 — specific error value**: `#expect(throws: E.case) { … }` (needs `Equatable`; `ReminderChangeError` gains it). (Not in the pilot.)
- **Force-unwrap of `cal.date(byAdding:…)`** → `try #require(…)` with the `@Test func` marked `throws` — SwiftFormat's `wrapConditionalBodies`/require conversion applied it; kept, it's the better idiom and behaviour-equivalent (clean failure vs crash).
- **`context` with a single `it`** → still nested as a `@Suite` struct (faithful; the context string carries real information in the test tree).
- **`expect(try! f())` on a throwing domain function** (TargetResolverSpec) → `@Test func … throws` + `#expect(try f() == …)`. Same as the `cal.date` force-unwrap rule: behaviour-equivalent, clean failure vs crash.

## The one `Sources/` change

`ReminderChangeError: Error` → `Error, Equatable` (`ReminderChangeParsing.swift:24`). Shipped with the RemindersLibTests commit (T024/T025). Enables `#expect(throws: ReminderChangeError.nothingToChange)` / `.unrecognizedRecurrence("garbage")` in `ChangeCommandSpec`. Matches `ReminderStoreError` / `CalendarStoreError` / `TextError`. `swift build` green, no behaviour change (`git diff main --stat -- '*/Sources/*'` = this one line).

---

## Per-target parity (SC-003)

| Target | `it` baseline | `@Test` after | Consolidations |
|---|---|---|---|
| GetClearKitTests | 212 | **212** ✓ | none |
| AppleEventKitSupportTests | 11 | **11** ✓ | none |
| AppleContactKitTests | 14 | **14** ✓ | none |
| ContactKitTests | 26 | **26** ✓ | none |
| TextLibTests | 70 | **70** ✓ | none |
| MailLibTests | 154 | **154** ✓ | none |
| ContactsLibTests | 60 | **60** ✓ | none |
| CalendarLibTests | 199 | **199** ✓ | none |
| RemindersLibTests | 327 | **327** ✓ | none |
| **Total** | **1,073** | **1,073** ✓ | none |

Every `it` maps 1:1 to a `@Test`, verbatim description, same matcher semantics. No two-inputs-same-path consolidations were taken — the census over-counted the opportunity; each `it` that looked redundant turned out to assert a distinct field or a distinct input shape.

---

## Phase 7 validation (SC results)

| SC | Check | Result |
|---|---|---|
| SC-001 | `./scripts/test` green on CLT-only | **1073 / 1073** in 384 suites |
| SC-003 | parity: `it` → `@Test` | 1,073 → 1,073, 0 consolidations |
| SC-004 | 5 consecutive runs identical | ✓ (0.04–0.06s each) |
| SC-005 | `--no-parallel` same result | ✓ 1073 / 1073 |
| SC-006 | `swift build -c release`, no new warnings | ✓ — the two spy `Sendable` warnings surfaced by the now-compiling test targets were fixed with `@unchecked Sendable`; a full clean test build now shows only the pre-existing `main.swift:18` `usage()` warning (`Sources/`, FR-011) |
| SC-007 | `.github/workflows/` unchanged vs `main` | ✓ empty diff |
| SC-008 | `Sources/` diff = `ReminderChangeError: Equatable` only | ✓ 1 file, 1 line |
| SC-010 | coverage within ~2 pts | aggregate 81.6% line (was 80.66%), RemindersLib 92.6% (was 91.4%) |
| SC-011 | no prefixed suite types | ✓ all `<Thing>Tests`, module-scoped |

---

## Parallel execution

Swift Testing runs `@Test`s in parallel by default (across suites and within them). The migration is parallel-clean with **nothing to serialize**:

- **Isolation model:** Swift Testing instantiates a fresh copy of the suite `struct` for every `@Test`. So a `let store = SpyStore()` (or `SpyContactStore` / `SpyCalendarStore` / `SpyMailClient` / `MockStore`) stored on a suite is private to one test — no two concurrently-running tests share a spy. This is why `beforeEach { store = Spy() }` → a stored `let` is a faithful translation, not just a convenient one.
- **Shared fixtures** hoisted to file scope (`private let all`, `private let cal`, `private let now`, `private let range`, `private let numbered`, …) are all read-only value types or arrays of them — safe to read concurrently.
- **`ActivityLogSpec`** is the only filesystem-touching suite; each nested suite instance builds its own `…appendingPathComponent("gc-test-\(UUID().uuidString)")` dir. Verified non-flaky under parallel and `--no-parallel`.
- **Verification:** 25 consecutive `./scripts/test` runs (5 at T015/T035 + 20 stress), every one `1073/1073` in 384 suites, identical; `--no-parallel` matches. No `@Suite(.serialized)` anywhere, none needed. Satisfies SC-004/SC-005 and the new constitution principle ("fix the isolation, don't serialize around it").
- **`@unchecked Sendable` on the two `Sendable`-protocol spies** (`SpyContactStore` → `ContactStore: Sendable`, `SpyMailClient` → `MailClient: Sendable`). Each carries mutable recording state, but the per-`@Test` suite instance means no spy is ever shared across concurrent tests — the annotation states that contract rather than serializing. Silences the two "error in Swift 6 language mode" warnings and unblocks a future move off `swiftLanguageModes: [.v5]`.
