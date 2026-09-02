# Contract — Documentation draft text

Draft replacements. Wording is for review during implementation, not frozen. The conventions that carry over from the Quick era are stated verbatim so nothing is lost in the framework swap.

---

## `CLAUDE.md:44` — the testing paragraph

> Test framework is **Swift Testing** (`import Testing`), run via `swift test`. It ships with the Swift toolchain — no Xcode, no XCTest. Each test file is named `*Spec.swift` and maps to exactly one source file. Structure: a top-level `@Suite` for the function or type under test, nested `@Suite`s for scenarios (what was `describe` → `context`), one `@Test` per behavior. One assertion (`#expect` / `#require`) per `@Test`. `@Test` descriptions are natural-English sentences describing the behavior — not restating the input. No two `@Test`s cover the same behavior; if two inputs hit the same code path, pick one. Unimplemented behavior is documented with a `@Test` that asserts the current (nil / empty) result and says "not yet supported" in its description. Suites run in parallel by default — tests must not share mutable state or depend on order.

## `CLAUDE.md:114` — Active Technologies bullet

> - Swift 6.0 (swift-tools-version: 6.0, language mode v5) + Swift Testing

## `review.md:92`

> **Framework: Swift Testing.** Each file is `*Spec.swift`, one per source file, using `@Suite` / `@Test` / `#expect`. Run with `swift test` — no Xcode required.

## `review.md:94`

> **Structure: `@Suite` → nested `@Suite` → `@Test`.** One assertion per `@Test`. Descriptions are natural-English sentences. No two `@Test`s test the same behavior — pick the most readable example. Tests run in parallel; no shared mutable state, no ordering assumptions.

*(`review.md:9` `swift test` — 0 failures, and `review.md:10` coverage item — unchanged.)*

---

## `.specify/memory/constitution.md` — new principle

Insert as a new `## ` section (placement: after "GetClearKit first", before "Timestamps come from the system clock" — or wherever fits the document's flow).

> ## Tests are Swift Testing, and they are code
>
> The test framework is Swift Testing (`import Testing`), run with `swift test`. It comes with the toolchain — a machine with the Command Line Tools and no Xcode can build and run the full suite. No test may reintroduce a dependency on XCTest or on Xcode.
>
> One test file per source file, named `*Spec.swift`. One `@Test` per behavior, one assertion per `@Test`, described in a natural-English sentence. Edge cases and bad input are first-class `@Test`s, not follow-ups. A new source file and its test file ship in the same commit.
>
> Suites run in parallel. A test that shares mutable state with another, or depends on execution order, is broken — fix the isolation, do not serialize around it.

---

## `ARCHITECTURE.md` — decision-log entry (new)

> ### Test framework: Swift Testing (2026-09-01)
>
> The suite moved from Quick + Nimble to Swift Testing (spec 016). Quick's `QuickSpec` subclasses `XCTestCase`, so every test transitively linked XCTest — which ships only with a full Xcode install, not the Command Line Tools. A CLT update in mid-2026 stopped bundling XCTest and `swift test` broke on every machine without Xcode; CI (Xcode-equipped runners) kept passing and masked it.
>
> This is the second round trip. Before 2026-04-11 (`99a20f6`) the tests were a hand-rolled `TestRunner` harness that existed specifically to avoid the XCTest/Xcode dependency. Adopting Quick + Nimble traded it back. Swift Testing — toolchain-bundled, no XCTest — solves it properly: the suite now builds and runs on CLT-only and on Linux.
>
> `swift-tools-version` moved 5.9 → 6.0 (Swift Testing's SwiftPM integration needs it); language mode stays v5 via package-level `swiftLanguageModes: [.v5]`. The five vestigial `*-cli/Package.swift` were deleted at the same time.

## `ARCHITECTURE.md:55` and `:148` — the ObjC-collision constraint

Both entries describe a Quick-only hazard (spec classes registered by bare ObjC class name, colliding across targets). Swift Testing suites are module-scoped Swift types; the hazard is gone. **Replace both with:**

> **Suite type naming.** Suite types are plain, unprefixed `<Thing>Tests` (e.g. `AddHandlerTests`), scoped to their test module. Identically-named suites in different targets (`RemindersLibTests.AddHandlerTests`, `ContactsLibTests.AddHandlerTests`) do not collide. Filenames stay `*Spec.swift`, one per source file.

## `ARCHITECTURE.md:98`

> - async `@Test` functions are `func …() async throws` — Swift Testing has no async/sync suite split

## `ARCHITECTURE.md:152` and `:166`

Re-measure after the migration and restate the counts (`swift test` total, per-target coverage). The `:152` "987 total suite tests" is already stale (survey counts 1,073 `it` blocks; a prior review recorded 1,032). Restate `:152` with the fresh `swift test` number and `:166` with fresh `xcrun llvm-cov` figures for `RemindersLib`.
