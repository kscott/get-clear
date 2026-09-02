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
- **2 pre-existing warnings, unchanged 5.9 → 6.0** (confirmed by `touch` + rebuild under `git stash`):
  - `Tests/ContactTestSupport/SpyContactStore.swift:4` — `contacts` mutable in a `Sendable` conformer ("error in Swift 6 language mode" — a warning under v5). Not fixed (out of scope; test-support file, not a `*Spec.swift`).
  - `Sources/GetClear/main.swift:18` — `usage()` result unused `[#no-usage]`. Not fixed (FR-011 — `Sources/`).

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
- **Bucket 2 — error-inspecting closure**: `let err = #expect(throws: T.self) { … }; #expect(err?.message.contains(…) == true)`. (Not exercised in the pilot — RemindersLibTests.)
- **Bucket 1 — specific error value**: `#expect(throws: E.case) { … }` (needs `Equatable`; `ReminderChangeError` gains it). (Not in the pilot.)
- **Force-unwrap of `cal.date(byAdding:…)`** → `try #require(…)` with the `@Test func` marked `throws` — SwiftFormat's `wrapConditionalBodies`/require conversion applied it; kept, it's the better idiom and behaviour-equivalent (clean failure vs crash).
- **`context` with a single `it`** → still nested as a `@Suite` struct (faithful; the context string carries real information in the test tree).

## The one `Sources/` change

`ReminderChangeError: Error` → `Error, Equatable` (`ReminderChangeParsing.swift`). Ships with the RemindersLibTests commit. Matches `ReminderStoreError` / `CalendarStoreError` / `TextError`.

---

## Per-target parity (SC-003)

| Target | `it` baseline | `@Test` after | Consolidations |
|---|---|---|---|
| GetClearKitTests | 212 | **212** ✓ | none |
| AppleEventKitSupportTests | 11 | **11** ✓ | none |
| AppleContactKitTests | 14 | **14** ✓ | none |
| ContactKitTests | 26 | _ | _ |
| TextLibTests | 70 | _ | _ |
| MailLibTests | 154 | _ | _ |
| ContactsLibTests | 60 | _ | _ |
| CalendarLibTests | 199 | _ | _ |
| RemindersLibTests | 327 | _ | _ |
| **Total** | **1,073** | _ | _ |
