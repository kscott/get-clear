<!--
Sync Impact Report
==================
Version change: (initial) → 1.0.0
Added sections: Core Principles (I–VIII), Suite Architecture, Development Standards, Governance
Modified principles: n/a (first ratification)
Templates updated:
  - .specify/templates/plan-template.md ✅ (no principle conflicts found)
  - .specify/templates/spec-template.md ✅ (no principle conflicts found)
  - .specify/templates/tasks-template.md ✅ (no principle conflicts found)
Deferred TODOs: none
-->

# Get Clear Constitution

## Core Principles

### I. Two Equal Modes

Get Clear works in two modes: direct CLI use (a person typing commands) and Claude-assisted use (Claude issuing commands on the user's behalf). These modes are equal. Neither is primary.

A command that only makes sense when Claude is driving it is broken. A command that Claude handles fine but feels awkward to type directly is also broken. Claude's ability to paper over a design problem does not make it not a problem.

The vocabulary is natural enough to type directly — not because direct use is the priority, but because that's the test. If it reads wrong on a command line, the design is wrong. If Claude has to work around it, the design is wrong. Both failure modes are equal failures.

Commands can be softer than traditional CLIs (`remove` not `delete`, `done` not `complete`) because in both modes the context provides the safety net: conversation history when Claude-assisted, the user's own judgment when direct. The safety comes from the design, not from intimidating word choices.

**Measure:** Could someone use the tool from a command reference card alone? And does Claude issue commands that would read naturally if the user had typed them? Both must be yes.

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

### VIII. Error Output Design *(needs further refinement)*

Three distinct cases. Three distinct treatments. Getting this wrong in either direction — too alarming, too silent, blaming the user for a tool failure — changes the entire feel of the tools. Error output is the last thing the user sees when something went wrong. It shapes trust more than any successful command.

**User input problems** — the user made a mistake the tool can understand.
*Examples: reminder not found, invalid date, unrecognized list name.*

The tool understood the intent. The data just didn't match. Output must be specific about what failed — not "error" but "No reminder found matching 'Pay rant'." Suggest a correction where confident, but don't guess. Never condescending.

Tone: *I understood what you were trying to do. Here's what I found.*
Exit non-zero. No stack trace.

**Syntax confusion** — the tool couldn't parse the intent.
*Examples: wrong number of arguments, unrecognized command, ambiguous input.*

Show just enough usage to guide — one line of syntax, not a wall of text. Don't echo back what the user typed. Point toward `help` for more, but don't make them go looking for the basics.

Tone: *Here's how this command works.*
Exit non-zero.

**Tool failure** — the tool broke, not the user.
*Examples: EventKit permission denied, JMAP token expired, unexpected crash, API unreachable.*

Be honest that something went wrong on the tool's side. Never blame the user or make them feel responsible. Where the failure is recoverable, say how — "Run `mail setup` to refresh your token." Where it is not, say that plainly. This is where future telemetry hooks in: if a crash is reportable, say so — "This looks like a bug. If you'd like to report it..." — but only when opt-in telemetry is configured.

Tone: *Something went wrong on our end. Not yours.*
Exit non-zero.

**Rules that apply to all three cases:**
- All errors go to stderr via `fail()` — never stdout
- Exit non-zero — always
- No silent failures — ever
- Brevity applies — errors are already friction; don't add to it
- No stack traces in production output — those go to the error log, not the screen

**Repeated syntax confusion is signal, not noise.** A pattern of the same syntax error — the same user, the same command, the same failure — points to a vocabulary gap or missing functionality. The tool is not supporting something people are trying to do. Error logs and telemetry must preserve enough context to surface these patterns. A cluster of syntax errors around a command is a feature request in disguise.

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

All implementation work MUST verify compliance with Core Principles I–VIII before merge. When a principle is in tension with a proposed feature, resolve the tension first — do not ship around it.

**Version**: 1.0.0 | **Ratified**: 2026-03-18 | **Last Amended**: 2026-03-18
