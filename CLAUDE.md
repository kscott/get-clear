# Get Clear — Claude Instructions

## Before writing any code

Read these files every session, without exception:

- `design.md` — product principles and command vocabulary; the ethos of the project
- `review.md` — engineering disciplines; read before closing any issue
- `ARCHITECTURE.md` — current structure and decision log
- `.specify/memory/constitution.md` — project constitution; principles that govern all decisions

Do not write a line of code until you have read all four. The engineering disciplines in `review.md` are inviolable.

## New features require SpecKit — no exceptions

Every new feature goes through the SpecKit workflow before any implementation code is written. Bug fixes do not require this.

**The workflow:**

1. `/speckit.specify <feature description>` — produces a spec (what and why; no implementation details). Creates a numbered feature branch under `specs/`.
2. `/speckit.plan` — produces a technical plan from the spec: research, data model, interface contracts.
3. `/speckit.implement` — implements from the plan.

Do not skip steps. Do not write implementation code while the spec is incomplete. Do not let "it's a small feature" justify bypassing the workflow — the workflow exists precisely because small features get built wrong when the what and why aren't settled first.

Past specs live in `specs/` (001 through 011). Read one before running SpecKit for the first time in a session to calibrate the expected format and depth.

## Engineering expectations — held without being asked

These are not reminders. They are the standard.

**Flag quality issues proactively.** If a function is too long, say so. If logic belongs in a Lib and is being written in `main.swift`, say so. If a pattern is being duplicated, say so. Do not wait to be asked.

**main.swift is dispatch-only.** Any logic you are tempted to write in `main.swift` belongs in the Lib. A `main.swift` longer than ~100 lines is a defect.

**Design the interface before writing the implementation.** Define inputs and outputs. Write the test. Then write the code. This order is not optional for Lib-target logic.

**Update ARCHITECTURE.md when something changes.** After any structural change — new file, new type, extracted function, deferred observation — add the appropriate entry. Decision log for decisions made. Improvement backlog for things noticed but not acted on. This is how continuity works across sessions; the document is the memory.

**Tests ship with the code.** Edge cases and bad input are first-class test cases. Not follow-ups.

**Tests are code — all rules apply.** One test file per source file. Test file structure mirrors source file structure. New source file and new test file ship in the same commit.

Test framework is **Swift Testing** (`import Testing`), run via `swift test`. It ships with the Swift toolchain — no Xcode, no XCTest. Each test file is named `*Spec.swift` and maps to exactly one source file. Structure: a top-level `@Suite` for the function or type under test, nested `@Suite`s for scenarios (what was `describe` → `context`), one `@Test` per behavior. One assertion (`#expect` / `#require`) per `@Test`. `@Test` descriptions are natural-English sentences describing the behavior — not restating the input. No two `@Test`s cover the same behavior; if two inputs hit the same code path, pick one. Unimplemented behavior is documented with a `@Test` that asserts the current (nil / empty) result and says "not yet supported" in its description. Suites run in parallel by default — tests must not share mutable state or depend on order.

---

## What this project is

Get Clear is a suite of five Swift CLIs connecting Claude to Apple Reminders, Calendar, Contacts, Mail, and Messages. It ships as a signed, notarized PKG installer and a curl one-liner.

Everything lives in this monorepo (migration #34 complete). Tool source lives under `<tool>-cli/Sources/` subdirectories. All standalone repos are archived. All issues tracked here.

## Development workflow

One issue at a time on a local feature branch.

```bash
git checkout -b issue-37       # start
# work, commit...
                               # review DoD, pick nits until satisfied
gh issue close 37              # close BEFORE merging — branch stays live until nothing is left to fix
git checkout main && git merge issue-37 && git branch -d issue-37
```

## Build and test

```bash
# All tests (run from monorepo root)
cd ~/dev/get-clear && swift test

# Build release and install a specific tool
cd ~/dev/get-clear && swift build -c release
cp .build/release/<tool>-bin ~/.local/bin/<tool>
```

## Key files

| File | Purpose |
|---|---|
| `design.md` | Product + engineering principles — read every session |
| `ARCHITECTURE.md` | Current structure, decisions, improvement backlog — read every session |
| `going-live.md` | Launch checklist — all blockers are pre-launch blockers, ordered by dependency |
| `Sources/GetClearKit/Commands.swift` | Command enum + runCLI — suite-wide dispatch |
| `Sources/GetClearKit/ArgParsing.swift` | Argument parsing — parseArgs, ParsedArgs |
| `pkg/resources/welcome.html` | PKG installer welcome page |
| `pkg/resources/conclusion.html` | PKG installer conclusion page |

## Active go-live blockers

All of these must be complete before public release. See `going-live.md` for full detail.

Done: #33 (Command enum), #34 (monorepo), #35–39 (business logic extraction), #139 (async/await), #144 (reminders second-pass), #150 (shared contact resolution), #147 (reminders three-tier), #143 (text three-tier), #141 (contacts three-tier), #154 (RemindersLib ValueChange retrofit), #140 (calendar three-tier), #142 (mail three-tier)

Remaining, in priority order:
- **#61** — Gmail support (hard launch blocker; depends on MailClient #142)
- **#53, #80, #68** — Feature additions: `calendar change`, move reminder to list, multi-recipient text
- **#40** — GetClearKit shared utilities (what command, multi-match, field updates, error type)
- **#41–45** — Test coverage for each tool's Lib targets
- **#30** — Bundle Claude Code skills with PKG/curl installer (independent)
- **#135** — Smoke tests: --version and --help for all five binaries

## Versioning

Two constants in each tool's `Version.swift`:
- `builtVersion` — this tool's semver
- `suiteVersion` — the PKG release version

Display: `reminders 1.3.1 (Get Clear 1.3.1)` — current suite version is 1.3.1

Use `scripts/bump-version <suite-version> [tool:version ...]` to bump. Never edit version constants by hand.

## Active Technologies
- Swift 6.0 (swift-tools-version: 6.0, language mode v5) + Swift Testing
- GetClearKit, ContactKit, AppleContactKit, ContactStoreFactory — shared suite and contact layers
- Contacts framework access via AppleContactKit boundary only; no writes
- Shared CLI argument parser in GetClearKit (`CommandArguments.swift`, spec 015) — per-command `CommandShape`; tools declare shapes, not parsers

## Recent Changes
- 015-argument-shape: Added Swift 6.0 (swift-tools-version: 6.0, language mode v5) + GetClearKit (new parser lives here); Swift Testing (toolchain-bundled)
