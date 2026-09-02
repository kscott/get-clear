# Contract — New constitution principle

The constitution (`.specify/memory/constitution.md`) has no testing principle today (verified — full read, 105 lines). FR-019a adds one. Draft:

---

## Tests are Swift Testing, and they are code

The test framework is Swift Testing (`import Testing`), run with `swift test`. It comes with the toolchain — a machine with the Command Line Tools and no Xcode can build and run the full suite. No test may reintroduce a dependency on XCTest or on Xcode.

One test file per source file, named `*Spec.swift`. One `@Test` per behavior, one assertion per `@Test`, described in a natural-English sentence — not a restatement of the input. Edge cases and bad input are first-class `@Test`s, not follow-ups. A new source file and its test file ship in the same commit.

Suites run in parallel. A test that shares mutable state with another, or depends on execution order, is broken — fix the isolation, don't serialize around it.

---

## Placement

After **"GetClearKit first"**, before **"Timestamps come from the system clock"** — it sits with the other "how we build" principles rather than the "how a tool behaves at runtime" ones.

## Consistency check

Must not contradict:
- `CLAUDE.md:44` (the fuller version — the constitution states the rule, `CLAUDE.md` shows the shape)
- `review.md:92,94`
- The constitution's own preamble: "When this document conflicts with `design.md`, update both." `design.md` has no testing section; if the implementer adds one, keep them in step.
