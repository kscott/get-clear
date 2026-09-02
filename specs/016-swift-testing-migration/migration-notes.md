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

## Canonical forms for the fiddly buckets (research R3 — validated in the pilot)

*To be filled in by T016 during the GetClearKitTests pilot.*

- **Bucket 3 — `fail()` in `guard case`**: `Issue.record("…")` in the `else` branch, then `return`. (GetClearKitSpec `parseArgs` tests.)
- **Bucket 2 — error-inspecting closure**: `let err = #expect(throws: T.self) { … }; #expect(err?.message.contains(…) == true)`.
- **Bucket 1 — specific error value**: `#expect(throws: E.case) { … }` (needs `Equatable`; `ReminderChangeError` gains it — see D-below).

## The one `Sources/` change

`ReminderChangeError: Error` → `Error, Equatable` (`ReminderChangeParsing.swift`). Ships with the RemindersLibTests commit. Matches `ReminderStoreError` / `CalendarStoreError` / `TextError`.

---

## Per-target parity (SC-003)

| Target | `it` baseline | `@Test` after | Consolidations |
|---|---|---|---|
| GetClearKitTests | 212 | _ | _ |
| AppleEventKitSupportTests | 11 | _ | _ |
| AppleContactKitTests | 14 | _ | _ |
| ContactKitTests | 26 | _ | _ |
| TextLibTests | 70 | _ | _ |
| MailLibTests | 154 | _ | _ |
| ContactsLibTests | 60 | _ | _ |
| CalendarLibTests | 199 | _ | _ |
| RemindersLibTests | 327 | _ | _ |
| **Total** | **1,073** | _ | _ |
