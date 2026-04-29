# CLI Suite — Design Principles

Covers: reminders-cli, calendar-cli, contacts-cli, mail-cli, text-cli

All code lives in the monorepo at `~/dev/get-clear/`. This document captures the principles that span the whole suite.

---

## Two equal modes

Get Clear works in two modes: a person typing commands directly, and Claude issuing commands on the user's behalf. These modes are equal. Neither is primary.

A command that only makes sense when Claude is driving it is broken. A command that Claude handles fine but feels awkward to type directly is also broken. Claude's ability to paper over a design problem does not make it not a problem.

**The vocabulary is natural enough to type directly** — not because direct use is the priority, but because that's the test. Commands can be softer than traditional CLIs (`remove` not `delete`, `done` not `complete`) because in both modes the context provides the safety net: conversation history when Claude-assisted, the user's own judgment when direct. The safety comes from the design, not from intimidating word choices.

**Measure:** Could someone use the tool from a command reference card alone? And does Claude issue commands that would read naturally if the user had typed them? Both must be yes.

---

## Tool identity: stateful vs. fire-and-forget

The suite divides cleanly into two kinds of tools:

**Stateful tools** — reminders, calendar, contacts
- Full lifecycle: add, read, change/rename, remove
- The data lives persistently (EventKit, CNContactStore)
- Claude can read back what it created and correct mistakes

**Fire-and-forget tools** — mail, text
- One-way dispatch: you compose and send, you don't read back in this CLI
- No list, show, or inbox commands — those belong in the native app
- `find` in mail is the one exception: it provides context *before* composing, not after sending (current code still uses `search` — tracked as mail #12)

The test for whether a command belongs in a tool: *does it fit the tool's identity?*
A `mail inbox` command would be wrong not because it's hard, but because mail is a
send tool. Same reasoning cut `text list` and `text show`.

---

## `done` not `complete`

`complete` is slightly formal — it asks the user to think like the app. `done` is the word that naturally ends the thought in conversation: "I'm done with that reminder." Claude translates that directly into `reminders done "Pay rent"` without the user having to shift register.

**Localization test:**

| Language | `complete` | `done` equivalent |
|---|---|---|
| French | `compléter` — technical, borrowed | `fini` / `terminé` — natural state words |
| Italian | `completare` — close but formal | `fatto` / `finito` — "fatto!" is quintessentially Italian for done |

`complete` localizes awkwardly — it sounds like a form field. The `done` *concept* localizes naturally in both languages even if the exact English word doesn't transfer. That confirms the instinct: `done` is grounded in human experience, `complete` is grounded in software.

---

## Add/remove symmetry

Every command that adds something must have a corresponding remove.

| Tool | Add | Remove |
|---|---|---|
| reminders | `add` | `remove` |
| calendar | `add` | `remove` |
| contacts | `add` | `remove` |
| contacts | `add <name> to <group>` | `remove <name> from <group>` |

**Why this matters for AI-assisted workflows:** Claude can add things incorrectly.
The only safe recovery is a remove command in the same tool. If remove doesn't exist,
a mistake requires opening the native app to fix. Add/remove pairs should ship
together — no add without its remove.

---

## Sequential commands and shared state

When two commands need to chain — where the output of one becomes the input of the
next — the first command must persist state for the second.

The canonical example: `mail search` → `mail reply`

- `search` finds messages and prints them numbered
- `reply` references a result by number and needs its message ID
- Without persistence (e.g. a temp file mapping numbers → IDs), reply can't work

Pattern: write last results to `~/.cache/<tool>/last-results` as JSON. The follow-on
command reads it and fails gracefully if it's stale or missing.

This is the design prerequisite before building any chained command. Don't build the
second command without the first having stable, referenceable output.

---

## Conversational design

Commands read as plain English, not POSIX syntax.

```bash
reminders add "Pay rent" march 1 repeat monthly
mail send Alice subject Lunch? body Free at noon
contacts change Bob phone 555-1234
```

**`rename` and `change` are distinct operations, not aliases.**

`rename` changes the identity of a record — the primary field by which it is
found, referenced, and talked about. A reminder's title, a contact's name. This
is closer to replacing the record than modifying it.

`change` modifies attributes — the things a record *has*: due date, phone number,
priority, note. These hang off the identity without affecting it.

```bash
reminders rename "Pay rent" "Pay mortgage"        # changes what it is
reminders change "Pay rent" friday priority high  # changes what it has
```

**Flags are wrong.** If you find yourself reaching for a flag, stop — that's a
signal to think harder. There is always a better way that fits the ethos of
these tools. The `--name` flag in `edit` was the proof: the right answer was a
dedicated `rename` command all along, and it earned its place on semantic grounds
— not just to avoid a flag.

The only flags in the entire suite are `--help`/`-h` and `--version`/`-v`,
and those exist solely because the outside world expects them from any CLI.
The suite also responds to the plain words `help` and `version` — no dashes needed.

```bash
reminders help       # plain word — conversational
reminders --help     # POSIX convention — for scripts and muscle memory
reminders version
reminders --version
```

When tempted by a flag, ask: *what command am I actually trying to express?*
`--name` → `rename`. `--draft` in mail is the current exception to audit next.

**Natural language keywords** — accept conjugations people naturally type:
`repeat`/`repeating`/`repeats`, `note`/`notes`. Don't invent syntax when English works.

---

## Setup is idempotent

`<tool> setup` is safe to re-run at any time:

- Always rebuilds the binary (keeps it current after a code update)
- Detects existing credentials and reuses them silently
- Only prompts for credentials when none are configured
- Passing a credential argument overrides for rotation: `mail setup <new-token>`

A user should never have to know or care whether this is their first run or their tenth.

---

## Command vocabulary

**When a vocabulary choice is uncertain, test it by translating to other languages.** The right word survives translation — its meaning is grounded in human experience, not software convention. A word that only makes sense in English UI context is a word borrowed from the wrong register. `done` and `find` both passed this test; `complete` and `search` did not.

Use the word you'd say to Claude in conversation:

| Technical word | Suite word | Rationale |
|---|---|---|
| create | `add` | "add a reminder", "add a contact" |
| delete | `remove` | softer; Claude provides the safety net |
| edit | `change` | "change the due date" — exactly how you'd say it |
| rename | `rename` | changes identity (the primary key); semantically distinct from `change` |
| search | `find` | the Finder, not the Searcher — macOS named it right; `find` expresses intent, not process |
| logged / no activity | `recorded` | "The log records what it saw — it makes no claim about what you did." Applies to output: "Nothing recorded" not "nothing logged" or "no activity." `logged` names the mechanism; `recorded` names the result. `no activity` implies the log captured everything — it didn't. |

**`find` not `search`**

`search` describes what you're doing along the way. `find` is the intent — what you want to end up with. The Finder is Apple's own proof: the whole identity of the app is built around *finding*, not searching. UNIX agrees (`find`, not `search`). And the imperative form confirms it: "find me meetings with Bob" is more natural than "search for meetings with Bob."

Localization test: French *trouver*, Italian *trovare*, German *finden* — every language uses the outcome verb as the imperative. That's the right register for a command.

`mail find` is the target vocabulary; current code still uses `search` (tracked as mail #12).

`to` and `from` as keywords handle membership naturally:
```
contacts add Bob to "Team Members"        # add to group
contacts remove Bob from "Team Members"   # remove from group
contacts add Bob email bob@example.com    # create contact
contacts remove Bob                       # delete contact
```

Four commands collapsed to two. The keyword disambiguates.

## Consistency across the suite

Things that must be the same in every tool:

- `rename` changes identity; `change` modifies attributes — distinct by design
- `setup` for first-time install + credentials (no separate `install` command)
- `help`, `--help`, `-h` all print usage and exit 0
- `--version`, `-v` print the version string and exit 0
- Errors go to stderr via `fail()`, exit non-zero
- No silent failures

---

## Emoji shortcode expansion *(planned — get-clear #17)*

User-supplied text strings (titles, notes, messages) will support Slack-style shortcodes: `:tada:` → 🎉, `:rocket:` → 🚀. This is a text preprocessing step applied before the string is saved or sent.

The expansion function will live in each `*Lib` so it is testable. The curated set covers the ~150 most common shortcodes (matching GitHub/Slack common usage) — not the full Unicode emoji list. The dictionary is embedded; no runtime dependency.

Scope: applied to any user-supplied free text — event titles, reminder titles, note fields, mail subject/body, SMS message body. Not applied to command keywords, calendar names, list names, or query strings.

**Not yet implemented.** Tracked in get-clear #17.

---

## Don't ship dead code

Stub functions that can't be implemented honestly get deleted, not left in.

The failure mode: `phoneLabel()` in text-cli always returned false, making the
mobile-number preference loop silently a no-op. The code looked like it was doing
something it wasn't. When a function can't be implemented correctly yet, remove
the call site too — don't leave the impression of working logic.

When features are removed, their supporting code goes with them. `resolveIdentifier()`
was written for `text list` and `text show`. When those commands were cut, the function
and its tests were deleted in the same commit.

---

## Repo structure: monorepo

All five tools and GetClearKit live in a single monorepo at `~/dev/get-clear/` (#34, completed 2026-04-16). Standalone per-tool repos are archived. One `Package.swift`, one CI run, one place for cross-cutting changes.

---

## Development workflow: feature branches

Work one issue at a time on a local feature branch. Merge to main when the issue is complete and all tests pass.

```bash
git checkout -b issue-36       # start of session
# ... commits ...
                               # review DoD, pick nits, add commits until satisfied
                               # read new files against engineering expectations in design.md
                               # run /simplify — reuse, quality, efficiency pass; fix before closing
gh issue close 36              # close the issue before touching main
git checkout main
git merge issue-36             # done — main moves in a meaningful unit
git branch -d issue-36
```

**Why:** committing directly to main during active work means there's no clean rollback point if something goes wrong mid-issue. A branch makes the completion event explicit — main only moves when the work is done. No PR or remote branch needed; this is local discipline, not process overhead.

**Close before merge, not after.** The issue stays open as long as the branch is live. Review the definition of done, pick any nits, and add commits until fully satisfied — the branch is still there. Close the issue only when nothing is left to fix. Merging to main is the final act, not the decision point.

**Scope:** one branch per going-live issue. Cross-cutting or exploratory work follows the same pattern. Branch names match the issue: `issue-36`, `issue-37`, etc.

---

## Architecture: the three-tier model

Every tool has three package targets:

`*Lib` — pure Swift, no framework imports, all domain logic, fully testable without permissions
`*EventKit` (or equivalent) — framework boundary; owns type conversion and store protocol implementation; pure assignment only, no business logic
`*CLI` — `main.swift` only; requests permissions, constructs the store, dispatches to handlers, prints output

Tests use **Quick + Nimble** across all repos. Run via `swift test`. No custom harness.

The rule: if it's a decision — which API to call, whether to set a field, how to interpret input — it belongs in Lib. If it's `field = value`, it stays at the boundary. Pure assignment at the boundary is acceptable without tests; conditionals there are a signal that logic has leaked.

### The conversion layer

Framework types (`EKReminder`, `EKEvent`, `CNContact`) are converted to pure value types (`ReminderItem`, `EventItem`, `ContactItem`) at the framework boundary — the moment the framework object is fetched. From that point on, all Lib logic operates on the pure type. The framework is never passed into the Lib.

This is what makes the Lib testable: a `ReminderItem` can be constructed in a test with no EventKit dependency. The conversion is a one-way door — in at the boundary, pure values everywhere else.

The store protocol (`ReminderStore`, `CalendarStore`, etc.) lives in Lib with a `resolve` default extension handling not-found/ambiguous lookup. The Apple-backed implementation (`AppleReminderStore`, etc.) lives in the framework boundary target.

reminders-cli is the complete reference implementation (#147). #140 (calendar), #141 (contacts), and #143 (text) are complete. #142 (mail) remains.

---

## Apple vs. Google backends

Three tools support a second backend via Google APIs: reminders-cli (Google Tasks), calendar-cli (Google Calendar), contacts-cli (Google Contacts). The native Apple backends remain the default.

### The offline advantage

The native Apple backends sync to the device. Reminders, Calendar, and Contacts all maintain a local store — you can read and write while offline, and changes queue for sync when the connection returns. This is the core reason the Apple backends are default and not just equal alternatives.

Google backends have no local cache. If the network is unavailable, every operation fails. For a tool designed to handle commitments reliably, that's a meaningful tradeoff the user needs to understand before switching.

### Mail is already the exception

mail-cli sends via SMTP, which requires a live connection regardless of backend. The offline story for mail is identical whether the backend is an SMTP relay or the Gmail API — both fail immediately without a connection. The Apple "offline advantage" does not apply to mail.

**Deferred send** is not handled automatically. A failed send fails — there is no retry queue. `mail send ... --draft` is the explicit offline workaround: it saves to IMAP and the user sends from their mail client when online. This is intentional. Silent retry queues create their own problems (did it send? when? did it fail quietly?). The user makes the call.

### Google Workspace service availability

Google Tasks, Contacts (People API), and Calendar are included with all personal Gmail accounts. On **Google Workspace** accounts, administrators can disable individual services. Tasks is the most commonly restricted — many enterprise and education environments turn it off. Calendar and Gmail are almost never disabled.

**The rule:** catch this at `setup` time, not at command time. After OAuth authorization, each tool's `setup google` flow makes a live validation call before writing anything to config or Keychain. If the service is unavailable:

```
✗ Google Tasks is not available on your account.
  Google Tasks is commonly disabled on Google Workspace accounts.
  Contact your administrator, or use the default Apple Reminders backend.
  Config was not saved.
```

Nothing is written if validation fails. Each backend is independent — a failed Tasks setup does not affect Calendar or Contacts setup.

### text-cli has no Google equivalent

Google Voice is the only Google SMS service, and it has no official API. text-cli stays Apple-only. This is not a gap to fill.

---

## Engineering disciplines — inviolable

These are not guidelines. They apply to every line of code written in this project,
by anyone, including Claude. When writing new code, check each one. When reviewing
code, reject anything that violates them.

### main.swift is dispatch-only

`main.swift` parses arguments, calls into Lib, and handles the process lifecycle.
That is all. Business logic, formatting, protocol details, and validation do not
belong there. A `main.swift` longer than ~100 lines is a signal something is wrong.

If you are tempted to write logic in `main.swift` because it is quick or convenient,
stop. Put it in the Lib. Quick and convenient is how the codebase got to 600-line
main files that cannot be tested.

### Every file has one job

Before creating a file, write one sentence describing what it does. If you cannot,
the design is not ready. The sentence becomes the file's header comment.

- `EventDateTime.swift` — Parses date/time strings into structured start/end/allDay values.
- `JMAPClient.swift` — Handles JMAP HTTP requests and responses.
- `ReminderFormatter.swift` — Formats reminder data for display output.

A file named `Helpers.swift` or `Utilities.swift` is a warning sign. Name things for
what they are. If the job cannot be named, it has not been thought through.

### Design the interface before writing the implementation

Before moving or writing any function, define what it takes as input and what it
returns. That contract is the design. If the contract is unclear, the implementation
will be unclear too.

Write the test first. The test defines the contract. Then write the implementation
that makes the test pass. This is not optional for logic that belongs in a Lib target.

### Moving code is not refactoring

A 600-line `main.swift` that becomes a 600-line `ToolLib.swift` is not progress.
Refactoring means improving the design: clearer responsibilities, better interfaces,
smaller functions, improved testability. The goal of an extraction is not to move
lines — it is to produce a type or function with a clear contract that can be tested.

When extracting from `main.swift`, do not copy the inline structure. Redesign it.

### Prefer pure functions

A function that takes values and returns a value is testable by definition. A function
that takes a mutable object and modifies it in place requires setting up state before
testing and inspecting state after. Prefer the former wherever the framework allows.

Where framework objects require mutation (EventKit, CNContacts), keep the mutation
thin and late. All decision logic — what to change, by how much, under what conditions
— belongs in pure functions in the Lib.

### No duplication without a documented reason

If the same logic appears in two places, it belongs in GetClearKit or a shared Lib.
The `what` command appearing identically in five `main.swift` files is the clearest
example of what this rule prevents.

The allowed exception: when two things look the same but mean different things.
Similarity is not duplication if the semantics differ. If you are keeping two
implementations separate intentionally, say so in a comment.

### Test coverage ships with the code

New commands and new Lib functions ship with tests. Not in a follow-up issue. Not
when there is time. Tests are part of the definition of done.

Edge cases and bad input are first-class test cases, not afterthoughts:
- What happens when required arguments are missing?
- What happens when a string contains special characters?
- What happens when the user passes a value that looks valid but isn't?

If a function is worth writing, the edge cases are worth testing.

### Tests are code — all rules apply

Every engineering discipline that applies to source files applies equally to test files.
There are no exceptions for tests.

**One file, one job.** A test file named `ReminderFormatterTests.swift` tests
`ReminderFormatter.swift` and nothing else. Stacking tests for multiple source files
into a single file is the same violation as stacking multiple jobs into a single
source file.

**Test file structure mirrors source file structure.** For every file in `*Lib/`,
there is a corresponding file in `Tests/*LibTests/`. When a new source file is created,
its test file is created in the same commit.

**Test framework is Quick + Nimble.** Each test file is a `QuickSpec` subclass named
`*Spec.swift`. Run the suite with `swift test`. No custom harness, no `main.swift`.

**Structure: describe → context → it.** `describe` names the function or type under
test. `context` names the scenario. `it` names one specific behavior. One assertion
per `it`. Test descriptions are natural English sentences describing behavior — not
restating the input. No two `it` blocks test the same behavior with different inputs;
pick the most readable example.

**Document absent behavior explicitly.** When a feature is not yet implemented, add
an `it` that asserts nil and includes "not yet supported" in the description. This
makes the gap visible and gives the future implementation a ready-made acceptance test.

A test suite that cannot be described in one sentence is not ready to be written.

### New code conforms to existing code

Before writing any new file, find and read its nearest equivalent elsewhere in the suite. In a monorepo, that equivalent is always nearby. The file structure, naming conventions, and internal patterns you find there are not suggestions — they are the standard. A new `main.swift` that doesn't match the others isn't just inconsistent; it's wrong.

This applies to every layer: dispatch conventions in `main.swift`, handler naming, formatter structure, test file layout. If something looks different from what already exists, that difference needs a reason. "I didn't look" is not a reason.

### Flag code quality proactively

When writing or reviewing code in this project, apply these disciplines without
being asked. If a function is growing too large, say so. If logic belongs in a Lib
and is being written in `main.swift`, say so. If a pattern is being duplicated, say so.

Do not wait to be asked if the code is good. The expectation is that every change
leaves the codebase in better shape than it found it.

---

## Suite name: Get Clear

### The name

**Get Clear** — not a state, a movement. The person this is built for isn't already there. They're busy, collaborative, juggling commitments to a lot of people. They want to feel balanced, in control, on top of things. Get Clear is the work of getting there.

The short form is **Clear**. The aspiration is getting clear.

---

### The pitch

You're not dropping balls — but you're watching all of them.

Every meeting promised, every email owed, every follow-up you said you'd send. They live in your head, which means they live in the way of everything else. The people you work with deserve better than "I meant to get back to you." So do you.

**Get Clear** is a suite of command-line tools that connects Claude directly to the things you actually use — Calendar, Reminders, Contacts, Mail, Messages. You tell Claude what needs to happen. It handles the machinery. The meeting gets added. The email goes out. The reminder is set. The follow-through is done.

Not a new system to learn. Not another app to check. Just you, Claude, and everything handled.

That's what getting clear feels like.

---

### The tools in this context

- **Reminders** — the promises you've made to yourself and others, surfaced and managed
- **Calendar** — your commitments in time, added and cleared without switching apps
- **Contacts** — the people at the center of it all, kept current
- **Mail** — getting the communication out, without the context switch
- **Messages** — the quick word, sent without breaking flow

Together they cover the full loop: *who* you're working with, *what* you've promised, *when* it's happening, and *how* you're staying in touch.

---

---

## Colored dot placement

Every item that belongs to a named container — a calendar, a reminder list — can carry a colored dot (the container's color, rendered as an ANSI-colored bullet). Where the dot lives depends on whether the view is interleaved or grouped.

**Interleaved view** — items from multiple containers displayed together without explicit grouping (e.g., `calendar today` showing events from multiple calendars sorted by time, `reminders today` showing reminders from multiple lists sorted by due date): **dot goes on each item**. Without it, the item's origin is invisible.

**Grouped view** — items displayed under their own named header (e.g., `reminders list` grouping reminders under bold list-name headers): **dot goes on the header, not on each item below**. Once the header identifies the container, repeating the dot on every item adds visual noise without adding information.

The test: *does the dot tell the user something the layout doesn't already tell them?* In an interleaved view, yes — origin is invisible without it. Under a named header, no — the header already names the origin.

---

## Color output

The suite uses ANSI color with automatic suppression — `isatty(STDOUT_FILENO)` and `NO_COLOR` are both checked at process startup. The result is stored once; there is no per-call re-evaluation.

**Three levels, not a palette.** The visual hierarchy has exactly three levels: bold (primary identifier), plain (body text), dim (metadata). Red is reserved for errors only — the `fail()` prefix. There is no fourth level, no accent color, no green for success. Three levels can be applied by rule; more levels require a style guide.

**Why dim, not color, for metadata.** A colored label (`blue` for dates, `yellow` for lists) creates a legend the user has to learn. Dim requires no legend — it means "this is here but not the thing you're looking for." The visual weight does the work without adding a new convention.

**`NO_COLOR` compliance follows https://no-color.org.** The presence of the variable (any value, including empty) disables color. Absence enables it, subject to isatty. This is the community standard and the only correct interpretation.

**contacts-cli was the reference implementation.** It was the first tool wired to GetClearKit ANSI helpers, and its color application (bold names, dim labels and metadata) set the pattern the other four tools follow. When a new tool is added, contacts-cli is the model to look at.

---

## Telemetry

Get Clear can collect anonymous usage data to improve the suite — but only with the user's explicit consent, and only ever to a first-party endpoint under the developer's control. No third-party analytics services.

**What's worth collecting:** command usage counts, error rates, version in use, and — most valuably — unrecognized command strings. When users consistently type `reminders search` or `calendar delete`, that's vocabulary friction the design hasn't resolved. Repeated misses tell their own story about what's missing or confusing. Success rates without failure rates are half the picture.

**What's never collected:** personal content of any kind — reminder titles, event names, contact details, message bodies, recipients. The tool handles private commitments; that content stays on the machine.

**Consent lives in the config file** (`~/.config/get-clear/config.toml`), written during `get-clear setup` after a single explicit yes/no prompt. The prompt names what is collected before asking — vague language is not acceptable. Consent stored in the config file leaves the door open for a future `get-clear settings` command that lists all configurable values and their current state, and a toggle subcommand to change them without re-running setup.

**The prompt must be specific.** Something like: *"Share anonymous usage data to help improve Get Clear? This includes command counts, unrecognized commands, and error rates. No reminder titles, event names, contacts, or message content is ever sent. (yes/no)"*

---

### Tagline candidates

- *Everything handled.*
- *All clear.*
- *Get clear. Stay clear.*
- *For people with a lot of people counting on them.*

