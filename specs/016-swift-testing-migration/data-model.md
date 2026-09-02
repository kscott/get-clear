# Phase 1 Data Model — Construct Mapping

The "entities" of this migration are Quick/Nimble constructs and their Swift Testing equivalents. Every `*Spec.swift` file is a mechanical application of these tables.

---

## Structural constructs

| Quick / Nimble | Swift Testing | Notes |
|---|---|---|
| `import Quick` / `import Nimble` | `import Testing` | `@testable import <ModuleUnderTest>` unchanged |
| `final class FooSpec: QuickSpec` + `override class func spec() { … }` | `@Suite("foo") struct FooTests { … }` | type renamed `*Spec` → `*Tests`, tool prefix dropped (R8) |
| `final class FooSpec: AsyncSpec` | `@Suite struct FooTests` | no async/sync suite split; async lives on the `@Test` |
| `describe("bar") { … }` | `@Suite("bar") struct Bar { … }` (nested) | nesting mirrors the old tree |
| `context("when baz") { … }` | `@Suite("when baz") struct WhenBaz { … }` (nested) | same as `describe` |
| `it("does the thing") { … }` | `@Test("does the thing") func doesTheThing() { … }` | description verbatim; func name is a slug, not significant |
| async `it("…") { await … }` | `@Test("…") func …() async throws { await … }` | |
| `beforeEach { store = Spy() }` (28×) | `let store = Spy()` stored property on the suite `struct` | fresh instance per `@Test` → isolation for free (R6) |
| `beforeEach { … filesystem setup … }` (6×, `ActivityLogSpec`) | per-instance `let tempDir = …UUID()…` + `init() throws { … }` | R6 |
| spec-scoped `let x = …` (shared read-only) | `static let x = …` or instance `let x = …` on the suite | |
| nested helper `func makeThing(…)` inside `describe` | method on the suite, or file-scope `func` | |
| file-private `private final class SpyX` | unchanged — same file, same declaration | |
| `fail("msg")` | `Issue.record("msg")` | R3 bucket 3 |
| `pending("…") { }` / an `it` that asserts nil + "not yet supported" | `@Test("… — not yet supported", .disabled("reason")) func …()` **or** keep the nil-assert `@Test` | project convention (CLAUDE.md:44) — see doc-text.md for the restated rule |

---

## Assertion constructs (the `#expect` table)

Counts from the survey census over 80 real spec files.

| Nimble | Count | Swift Testing |
|---|---|---|
| `expect(a) == b` | ~631 | `#expect(a == b)` |
| `expect(a) == true` | 102 | `#expect(a)` |
| `expect(a) == false` | 35 | `#expect(!a)` |
| `expect(a) == nil` | 3 | `#expect(a == nil)` |
| `expect(a) != b` | 3 | `#expect(a != b)` |
| `expect(a) > b` / `< b` / `<= b` | 7 | `#expect(a > b)` / … |
| `expect(a).to(beNil())` | 35 | `#expect(a == nil)` |
| `expect(a).toNot(beNil())` / `.notTo(beNil())` | 17 | `#expect(a != nil)`; use `try #require(a)` when a later line needs `a` unwrapped |
| `expect(a).to(beEmpty())` | 22 | `#expect(a.isEmpty)` |
| `expect(a).toNot(beEmpty())` | 8 | `#expect(!a.isEmpty)` |
| `expect(a).to(contain(x))` | 191 | `#expect(a.contains(x))` |
| `expect(a).toNot(contain(x))` / `.notTo(contain(x))` | 26 | `#expect(!a.contains(x))` |
| `expect(a).to(haveCount(n))` | 8 | `#expect(a.count == n)` |
| `expect(a).to(beginWith(p))` | 10 | `#expect(a.hasPrefix(p))` |
| `expect(a).toNot(beginWith(p))` | 3 | `#expect(!a.hasPrefix(p))` |
| `expect { try f() }.to(throwError())` | 32 | `#expect(throws: (any Error).self) { try f() }` |
| `await expect { try await f() }.to(throwError())` | (subset of above) | `await #expect(throws: (any Error).self) { try await f() }` |
| `expect { }.to(throwError(errorType: T.self))` | 7 | `#expect(throws: T.self) { }` |
| `expect { }.notTo(throwError())` | 4 | `#expect(throws: Never.self) { }` |
| `expect { }.to(throwError(E.specificCase))` | ~10 | `#expect(throws: E.specificCase) { }` (E must be `Equatable` — R3 bucket 1) |
| `expect { }.to(throwError { (e: T) in expect(e.message).to(contain(s)) })` | 16 | `let err = #expect(throws: T.self) { }; #expect(err?.message.contains(s) == true)` (R3 bucket 2) |
| `guard case .x = v else { fail("…") }` | `guard case .x = v else { Issue.record("…"); return }` (R3 bucket 3) |

**Never appear** (verified zero hits — no translation needed): `equal()`, `beTrue()`/`beFalse()`, `beCloseTo`, `beGreaterThan`/`beLessThan` (the operator forms are used), `beIdenticalTo`, `beAKindOf`, `satisfyAllOf`, `allPass`, `endWith`, `match(` regex, `toEventually`/`waitUntil`, `sharedExamples`/`itBehavesLike`, `afterEach`, `beforeSuite`, `xit`/`fit`, custom matchers.

---

## Manifest

| Element (root `Package.swift`) | Before | After |
|---|---|---|
| line 1 | `// swift-tools-version: 5.9` | `// swift-tools-version: 6.0` |
| `Package(...)` args | `name`, `platforms`, `products`, `dependencies`, `targets` | + `swiftLanguageModes: [.v5]` |
| `dependencies` | `[Quick from 7.0.0, Nimble from 13.0.0]` | `[]` (remove the key entirely) |
| each of 9 `.testTarget(dependencies:)` | `[<lib>, .product("Quick", "Quick"), .product("Nimble", "Nimble")]` | `[<lib>]` (+ `"ContactTestSupport"` where already present) |
| everything else (products, target paths, `linkedFramework`, `exclude`) | — | unchanged |

| File | Fate |
|---|---|
| root `Package.resolved` | regenerate — `"version": 2` → `3`, 7 pins → 0 |
| `.swift-version` | `5.9` → `6.0` |
| `reminders-cli/Package.swift`, `.../Package.resolved` | delete |
| `calendar-cli/Package.swift`, `.../Package.resolved` | delete |
| `contacts-cli/Package.swift`, `.../Package.resolved` | delete |
| `mail-cli/Package.swift`, `.../Package.resolved` | delete |
| `text-cli/Package.swift`, `.../Package.resolved` | delete |
| `{reminders,calendar,contacts,mail,text}-cli/.github/` | delete (dead workflows) |

---

## The one production change

| File | Change |
|---|---|
| `reminders-cli/Sources/RemindersLib/ReminderChangeParsing.swift:24` | `public enum ReminderChangeError: Error` → `public enum ReminderChangeError: Error, Equatable` |

Behavior-preserving; matches `ReminderStoreError`, `CalendarStoreError`, `TextError`. Recorded in migration notes as FR-011's permitted exception.

---

## Suite/test inventory (parity baseline for SC-003)

| Target | Files | `it` blocks | → `@Test` count expected |
|---|---|---|---|
| GetClearKitTests | 7 | 212 | 212 (± listed consolidations) |
| ContactKitTests | 3 | 26 | 26 |
| AppleContactKitTests | 1 | 14 | 14 |
| AppleEventKitSupportTests | 1 | 11 | 11 |
| CalendarLibTests | 19 | 199 | 199 |
| ContactsLibTests | 12 | 60 | 60 |
| MailLibTests | 11 | 154 | 154 |
| RemindersLibTests | 19 | 327 | 327 |
| TextLibTests | 7 | 70 | 70 |
| **Total** | **80** | **1,073** | **1,073** |

`describe` ×124 + `context` ×260 → ~384 nested `@Suite` types. A `@Test` may be consolidated with another only when both asserted the identical thing on identical input; each such case is listed in the per-target commit message and the final notes.
