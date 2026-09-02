# Contract — Migration Rules (invariants for every file rewrite)

Every `*Spec.swift` rewrite MUST satisfy all of these. The per-target commit is not done until they hold for that target.

## Structural

1. **File keeps its name.** `AddHandlerSpec.swift` stays `AddHandlerSpec.swift`.
2. **Top-level suite type = `<Thing>Tests`**, unprefixed, `@Suite("<original describe string>")`. `CalendarAddHandlerSpec` → `AddHandlerTests`.
3. **`describe` / `context` nesting is preserved** as nested `@Suite` structs with the original description strings. Nesting depth matches the original (including the one 3-level file, `OptionsParsingSpec`).
4. **One `it` → one `@Test`.** No `it` is dropped. The only permitted reduction: two `it`s asserting the identical behaviour on identical input collapse to one `@Test` — and that specific case is named in the commit message. SC-003 reconciles counts per target.
5. **`@Test` description = the `it` string, verbatim.** Natural-English sentence, unchanged.
6. **`beforeEach` → per-instance state**: stored `let`/`var` on the suite struct, or `init()` / `init() async throws`. Never a shared/static mutable. A fresh suite instance per `@Test` is the isolation model.
7. **`AsyncSpec` → plain `@Suite`**; its async `it`s → `@Test func …() async throws`.
8. **File-private test doubles stay in the file**, declaration unchanged.

## Assertions

9. **Use the `#expect` table in `data-model.md`.** No matcher outside that table should appear; if the rewrite needs one, stop — it means the source used something the census missed, and it gets handled explicitly (noted), not improvised.
10. **Specificity is preserved (FR-008).** `throwError(errorType: T.self)` → `#expect(throws: T.self)`. `throwError(E.case)` → `#expect(throws: E.case)`. `throwError { inspect }` → returned-error + follow-up `#expect`. Never weaken to a bare `#expect(throws:)` where the original checked more.
11. **`try #require` where a `nil` check guards later use** of the value; plain `#expect(x != nil)` where it does not.
12. **`fail()` → `Issue.record()`** with the same message.

## Non-negotiables

13. **No change under `Sources/`** except `ReminderChangeError: Equatable` (one word, `ReminderChangeParsing.swift`). Any other `Sources/` diff is a bug in the migration.
14. **`swift build` stays green after every commit.**
15. **`swift test --filter <Target>` is green** at the end of that target's commit, run on the Command Line Tools with no Xcode.
16. **`swiftformat --lint .` is clean** (the `.githooks/pre-push` gate) — follow `sortImports` (`import Testing` alphabetized with the others).
17. **Test descriptions, behaviour coverage, and edge-case tests are carried over unchanged.** This migration does not improve, add, or remove test logic (spec Out of Scope).

## Verification per target commit

```
swift build                          # green
swift test --filter <Target>         # green, on CLT-only
swift test --filter <Target>         # ×5, identical
swift test --filter <Target> --no-parallel   # green
swiftformat --lint <target test dir> # clean
grep -c 'it(' <files>  vs  grep -c '@Test' <files>   # reconciled
```
