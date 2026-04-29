# Get Clear — Claude Instructions

## Before writing any code

Read these files every session, without exception:

- `design.md` — product principles, command vocabulary, architecture rules
- `ARCHITECTURE.md` — current structure, decision log, improvement backlog
- `.specify/memory/constitution.md` — project constitution; principles that govern all decisions

Do not write a line of code until you have read all three. The engineering disciplines in `design.md` are inviolable. The improvement backlog in `ARCHITECTURE.md` is the memory across sessions.

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

Test framework is **Quick + Nimble** across all repos. Run via `swift test`. Each test file is a `QuickSpec` subclass named `*Spec.swift`. Structure: `describe` (function/type under test) → `context` (scenario) → `it` (single behavior). One assertion per `it`. Test descriptions are natural English sentences describing behavior — not restating the input. No duplicate tests for the same behavior; if two inputs hit the same code path, pick one. Unimplemented behavior is documented with an `it` that asserts nil and says "not yet supported" in the description.

---

## What this project is

Get Clear is a suite of five Swift CLIs connecting Claude to Apple Reminders, Calendar, Contacts, Mail, and Messages. It ships as a signed, notarized PKG installer and a curl one-liner.

Everything lives in this monorepo (migration #34 complete). Tool source lives under `<tool>-cli/Sources/` subdirectories. All standalone repos are archived. All issues tracked here.

## Development workflow

One issue at a time on a local feature branch. See `design.md` for full rationale.

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

Done: #33 (Command enum), #34 (monorepo), #35–39 (business logic extraction), #139 (async/await), #144 (reminders second-pass), #150 (shared contact resolution), #147 (reminders three-tier), #143 (text three-tier), #141 (contacts three-tier), #154 (RemindersLib ValueChange retrofit), #140 (calendar three-tier)

Remaining, in priority order:
- **#142** — MailClient protocol abstraction (use #147 as template)
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
- Swift 5.9 (swift-tools-version: 5.9) + Quick + Nimble (testing)
- GetClearKit, ContactKit, AppleContactKit, ContactStoreFactory — shared suite and contact layers
- Contacts framework access via AppleContactKit boundary only; no writes
