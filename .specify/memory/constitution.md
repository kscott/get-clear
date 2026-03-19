<!--
Sync Impact Report
==================
Version change: (initial) → 1.0.0
Added sections: Core Principles (I–VII), Suite Architecture, Development Standards, Governance
Modified principles: n/a (first ratification)
Templates updated:
  - .specify/templates/plan-template.md ✅ (no principle conflicts found)
  - .specify/templates/spec-template.md ✅ (no principle conflicts found)
  - .specify/templates/tasks-template.md ✅ (no principle conflicts found)
Deferred TODOs: none
-->

# Get Clear Constitution

## Core Principles

### I. Claude-First, Human-Usable

Get Clear is designed first for use through Claude and second as a standalone CLI. The primary operator is an AI in a conversation — not a human typing blind. This changes the design frame: commands can be softer (`remove` not `delete`) because the conversation history is the undo log and "oops" is a complete recovery instruction.

Every command MUST also be usable and legible without Claude. If a command only makes sense when an AI is driving it, the design is wrong. The vocabulary is natural enough that a person can type it directly. Claude is the accelerant, not the requirement.

**Measure:** Could someone use the tool from a command reference card alone, with no AI assistance? If yes, the design is right.

### II. Conversational Command Vocabulary

Commands read as plain English, not POSIX syntax. The vocabulary mirrors how you'd naturally talk to Claude:

| Technical word | Suite word | Rationale |
|---|---|---|
| create | `add` | "add a reminder", "add a contact" |
| delete | `remove` | softer; Claude provides the safety net |
| edit | `change` | "change the due date" — exactly how you'd say it |
| — | `rename` | changes identity (the primary key); semantically distinct from `change` |
| search | `find` | the Finder, not the Searcher; `find` expresses intent, not process |
| complete | `done` | "I'm done with that" — grounded in human experience, not software |

**`rename` and `change` are distinct, non-interchangeable operations.** `rename` changes the identity of a record (its title or name — the field by which it is found). `change` modifies attributes that hang off the identity (due date, phone number, priority, note). No tool may use `rename` and `change` as aliases.

**Flags are wrong.** The only flags in the entire suite are `--help`/`-h` and `--version`/`-v`. Both also respond to plain words `help` and `version` — no dashes required. When tempted by a flag, stop: that is a signal to find the right command name instead. The `--name` flag in an earlier `edit` command was the proof — the right answer was `rename` all along.

**Vocabulary test:** When a word choice is uncertain, translate it. The right word survives translation — its meaning is grounded in human experience, not software convention. `done` → *fini/fatto*. `find` → *trouver/trovare/finden*. Both pass. `complete` and `search` do not.

**Tone extends to output, not just commands.** The vocabulary discipline that produces `done` instead of `complete` applies equally to what the tools say back. Output that reads like a report is wrong in the same way a flag is wrong — it's the wrong register. `recap` output should feel like progress, not an audit. The affirmative tone is a design constraint, not a style preference.

**Brevity is the work.** Short output is not lazy — it's disciplined. Every word in tool output must earn its place. Do the extra work to make things tighter. The right sentence is shorter than the first draft.

### III. Add/Remove Symmetry (NON-NEGOTIABLE)

Every command that adds something MUST have a corresponding remove. Add and remove MUST ship together — no add without its remove.

**Why this matters:** Claude can add things incorrectly. The only safe recovery in the same tool is a remove command. Without it, a mistake requires opening a native app. This is a correctness constraint, not a style preference.

Applies to records and to group membership:
```
contacts add Bob to "Team Members"    ↔  contacts remove Bob from "Team Members"
reminders add "Pay rent" ...          ↔  reminders remove "Pay rent"
```

### IV. Tool Identity: Stateful vs. Fire-and-Forget

The suite divides cleanly into two identities:

**Stateful tools** — reminders, calendar, contacts
- Full lifecycle: add, read, change/rename, remove
- Data persists (EventKit, CNContactStore)
- Claude can read back what it created and correct mistakes

**Fire-and-forget tools** — mail, sms
- One-way dispatch: compose and send; no read-back in this CLI
- No `list`, `show`, or inbox commands — those belong in the native app
- `find` in mail is the exception: it provides context *before* composing, not after sending

**Test for new commands:** Does this command fit the tool's identity? A `mail inbox` command is wrong not because it's hard, but because mail is a send tool.

### V. Lib/CLI Architecture

Every tool MUST have two targets:

**`*Lib`** — pure Swift, no system framework imports, fully testable without permissions. All business logic, parsing, formatting, and data manipulation live here.

**`*CLI`** — framework access (EventKit, Contacts, Security, URLSession), thin dispatch layer. If you want to write a test for something in `main.swift`, that is a signal it belongs in the Lib.

The boundary is enforced by not importing system frameworks in the Lib target.

### VI. Shared Logic in GetClearKit (NON-NEGOTIABLE)

GetClearKit is the shared Swift package in the umbrella repo. **If logic is shared across two or more tools, it MUST live in GetClearKit — never duplicated across tool repos.**

What belongs in GetClearKit:
- `ANSI.swift` — bold/dim/red with isatty + NO_COLOR detection
- `Fail.swift` — `fail()` — red-prefixed error to stderr, exit non-zero
- `Flags.swift` — `isVersionFlag()`, `isHelpFlag()`
- `DateParser.swift` — natural language date parsing shared between reminders and calendar
- `RangeParser.swift` — time range parsing for calendar

The propagation rule: if you are writing the same logic in two tool repos, stop. Extract it to GetClearKit first, then use it from both.

### VII. No Dead Code

Stub functions that cannot be implemented honestly MUST be deleted, not left in. The failure mode is code that looks like it does something it doesn't — this masks bugs and misleads future work.

When features are removed, their supporting code goes with them in the same commit. When a function cannot be implemented correctly yet, remove the call site too — do not leave the impression of working logic.

## Suite Architecture

### Repo Structure

Six repos: one per tool (`reminders-cli`, `calendar-cli`, `contacts-cli`, `mail-cli`, `sms-cli`) plus the umbrella `get-clear` repo that hosts GetClearKit, the MCP server, and suite-level documentation.

Per-tool repos provide: clean versioning and changelogs, scoped GitHub issues and PRs, per-tool releases in the PKG installer.

GetClearKit is a Swift package dependency declared in each tool's `Package.swift`. Changes to GetClearKit require updating each dependent tool. When GetClearKit churn increases or cross-cutting changes become the norm, revisit monorepo migration (one-time cost: git history, issue URLs, install scripts).

### The MCP Server

The MCP server is a suite-level project in `get-clear/mcp/`. It is not a per-tool concern. A single server exposes the whole suite to Claude: the value compounds across tools in a single conversation.

The MCP server shells out to the installed binaries. This keeps the CLIs clean and the MCP layer independently deployable.

### Sequential Commands and Shared State

When two commands must chain (output of one becomes input of the next), the first command MUST persist state. Pattern: write last results to `~/.cache/<tool>/last-results` as JSON. The follow-on command reads it and fails gracefully if stale or missing. Do not build the second command without the first having stable, referenceable output.

### Activity Log

Every command that changes something (`add`, `remove`, `done`, `change`, `send`) MUST write a timestamped entry to a daily log file:
`~/.local/share/get-clear/log/YYYY-MM-DD.log`

Read-only commands (`list`, `find`, `show`) do not log — they are context, not accomplishments.

The `what` command surfaces the log:
```
reminders what      # completions in reminders today
calendar what       # events added or removed today
get-clear what      # everything, across all tools, today
```

### Setup Is Idempotent

`<tool> setup` is safe to re-run at any time. It rebuilds the binary, reuses existing credentials silently, and only prompts when no credentials are configured. Passing a credential argument overrides for rotation. A user should never need to know or care whether this is their first run or their tenth.

## Development Standards

### Testing

Every tool ships with a test suite in its `*Lib` target. Tests are written before implementation for new features. Test files live in `Tests/` inside each tool repo; GetClearKit tests run via `swift run getclearkit-tests`.

Current test counts (targets):
- reminders-cli: 188 tests
- calendar-cli: 89 tests
- contacts-cli: 31 tests
- mail-cli: 50 tests
- sms-cli: 36 tests
- GetClearKit: 185 tests

### Versioning and Distribution

Tools are versioned with MAJOR.MINOR.PATCH. The umbrella `get-clear.pkg` tracks the suite. `scripts/bump-version X.Y.Z` bumps VERSION, commits, pushes; CI handles the release.

Version 1.0.0 ships publicly when: Phase 1 (README + why.md) is complete and Phase 2 (clean-machine install validation) passes.

### Emoji Shortcode Expansion

User-supplied text strings support Slack-style shortcodes (`:tada:` → 🎉). The expansion function lives in each `*Lib` (testable). Applied to: event titles, reminder titles, note fields, mail subject/body, SMS message body. Not applied to: command keywords, calendar/list names, query strings.

## Governance

This constitution supersedes all other development guidance when conflicts arise. design.md and vision.md are the narrative source; this constitution is the authoritative rule set.

**Amendment procedure:**
1. Propose the amendment in a PR with rationale
2. Bump `CONSTITUTION_VERSION` per semantic versioning (MAJOR: backward-incompatible governance/principle removal; MINOR: new principle or material expansion; PATCH: clarification, wording)
3. Update `LAST_AMENDED_DATE` to the merge date
4. Propagate changes to templates if affected

All implementation work MUST verify compliance with Core Principles I–VII before merge. When a principle is in tension with a proposed feature, resolve the tension first — do not ship around it.

**Version**: 1.0.0 | **Ratified**: 2026-03-18 | **Last Amended**: 2026-03-18
