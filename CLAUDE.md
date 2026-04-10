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

---

## What this project is

Get Clear is a suite of five Swift CLIs connecting Claude to Apple Reminders, Calendar, Contacts, Mail, and Messages. It ships as a signed, notarized PKG installer and a curl one-liner.

- Umbrella repo: `~/dev/get-clear/` — GetClearKit shared library, PKG, scripts
- Tool repos: `~/dev/reminders-cli/`, `~/dev/calendar-cli/`, `~/dev/contacts-cli/`, `~/dev/mail-cli/`, `~/dev/text-cli/`
- Monorepo migration planned — tracked in get-clear #34

## Build and test

```bash
# GetClearKit tests
cd ~/dev/get-clear && swift run getclearkit-tests

# Individual tool — build release and install
cd ~/dev/<tool>-cli && swift build -c release
cp .build/release/<tool>-bin ~/.local/bin/<tool>

# Individual tool — run tests
cd ~/dev/<tool>-cli && swift build && swift run <tool>-tests
```

## Key files

| File | Purpose |
|---|---|
| `design.md` | Product + engineering principles — read every session |
| `ARCHITECTURE.md` | Current structure, decisions, improvement backlog — read every session |
| `going-live.md` | Launch checklist — all Phase 4 items are pre-launch blockers |
| `Sources/GetClearKit/Commands.swift` | Command enum + runCLI — suite-wide dispatch |
| `Sources/GetClearKit/ArgParsing.swift` | Argument parsing — parseArgs, ParsedArgs |
| `pkg/resources/welcome.html` | PKG installer welcome page |
| `pkg/resources/conclusion.html` | PKG installer conclusion page |

## Active go-live blockers (Phase 4)

All of these must be complete before public release. See `going-live.md` for full detail.

- **#33** — Command enum + runCLI across all tools (contacts done; reminders, calendar, mail, text remain)
- **#34** — Monorepo migration
- **#35–39** — Extract business logic from each tool's main.swift into Lib targets
- **#40** — GetClearKit shared utilities (what command, multi-match, field updates, error type)
- **#41–45** — Test coverage for each tool

## Versioning

Two constants in each tool's `Version.swift`:
- `builtVersion` — this tool's semver
- `suiteVersion` — the PKG release version

Display: `reminders 1.3.0 (Get Clear 1.3.0)`

Use `scripts/bump-version <suite-version> [tool:version ...]` to bump. Never edit version constants by hand.
