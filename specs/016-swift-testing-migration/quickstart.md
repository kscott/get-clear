# Quickstart — Migrating one `*Spec.swift` file

The recipe applied 80 times. Example: `Tests/GetClearKitTests/RangeParserSpec.swift`.

## Before

```swift
import Foundation
import GetClearKit
import Nimble
import Quick

final class RangeParserSpec: QuickSpec {
    override class func spec() {
        let cal = Calendar.current

        describe("parseRange") {
            context("single-day shorthands") {
                it("'today' resolves to today") {
                    expect(parseRange("today").map { cal.isDate($0.start, inSameDayAs: Date()) }) == true
                }
                it("'today' is a single-day range") {
                    expect(parseRange("today")?.isSingleDay) == true
                }
            }
            context("bad input") {
                it("an empty string returns nil") {
                    expect(parseRange("")).to(beNil())
                }
            }
        }
    }
}
```

## After

```swift
import Foundation
@testable import GetClearKit
import Testing

@Suite("parseRange")
struct RangeParserTests {
    static let cal = Calendar.current

    @Suite("single-day shorthands")
    struct SingleDayShorthands {
        @Test("'today' resolves to today")
        func todayResolvesToToday() {
            #expect(parseRange("today").map { RangeParserTests.cal.isDate($0.start, inSameDayAs: Date()) } == true)
        }

        @Test("'today' is a single-day range")
        func todayIsSingleDay() {
            #expect(parseRange("today")?.isSingleDay == true)
        }
    }

    @Suite("bad input")
    struct BadInput {
        @Test("an empty string returns nil")
        func emptyStringReturnsNil() {
            #expect(parseRange("") == nil)
        }
    }
}
```

## Steps

1. **Imports**: `import Quick` / `import Nimble` → `import Testing`. Keep `@testable import <Module>`. Let `sortImports` order them (`swiftformat` will tell you).
2. **Class → suite**: `final class XSpec: QuickSpec { override class func spec() {` → `@Suite("<outer describe string>") struct XTests {`. Drop the tool prefix.
3. **`describe` / `context` → nested `@Suite` struct** with the same description string. Pick a PascalCase type name from the string.
4. **`it("sentence") {` → `@Test("sentence") func sentenceSlug() {`**. The func name is a slug — not significant, keep it readable.
5. **Assertions**: apply the `#expect` table (`data-model.md`). `expect(a) == b` → `#expect(a == b)`; `.to(beNil())` → `#expect(a == nil)`; `.to(contain(x))` → `#expect(a.contains(x))`; etc.
6. **Throwing**: see `research.md` R3.
   - bare → `#expect(throws: (any Error).self) { … }`
   - `errorType: T.self` → `#expect(throws: T.self) { … }`
   - `E.specificCase` → `#expect(throws: E.specificCase) { … }` (E is `Equatable`)
   - inspecting closure → `let err = #expect(throws: T.self) { … }; #expect(err?.message.contains(…) == true)`
7. **`beforeEach { store = Spy() }` → `let store = Spy()`** stored on the suite struct (or the nested one that used it). Shared `let x` at `spec()` scope → `static let x` on the outer suite (reference it as `OuterType.x` from nested suites) or repeat as an instance `let`.
8. **async**: `AsyncSpec` → `@Suite`; async `it` → `@Test func …() async throws`; `await expect { }.to(throwError())` → `await #expect(throws:) { }`.
9. **`fail("m")` → `Issue.record("m")`**; in a `guard case … else { }`, add `return` after.
10. **File-private doubles**: leave them; they still compile.

## Verify (per file, then per target)

```
swift build                                   # green
swift test --filter <Target>                  # green, on CLT-only
swift test --filter <Target>                  # run ×5 — identical
swift test --filter <Target> --no-parallel    # green
swiftformat --lint <dir>                      # clean
grep -c 'it(' <old>  ==  grep -c '@Test' <new>   # or a listed consolidation
```

## Gotchas

- **`try #require` vs `#expect(x != nil)`**: use `#require` only when the next line dereferences `x`. `let v = try #require(optional); #expect(v.field == …)`.
- **Nested-suite access to outer state**: nested `struct`s don't see the outer struct's instance properties. Use `static let` on the outer type, or duplicate the `let` in the nested suite.
- **`@Test` with no `throws` calling a `throws` fn**: mark the func `throws`. Swift Testing reports a thrown error as a test failure — that's usually what you want; use `#expect(throws:)` only when the throw is the assertion.
- **`ActivityLogSpec` only**: each temp dir must be `…appendingPathComponent("gc-test-\(UUID().uuidString)")` per suite instance. Do not share one across the file. Run it ×5 to confirm before moving on.
- **SwiftFormat `--swift-version`**: after `.swift-version` → `6.0`, `swiftformat` enables a few version-gated rules across the whole tree. Run `swiftformat --lint .` (not just the test dir) in the pilot to catch any new `Sources/` finding.
