# CLI Suite — Design Principles

Covers: reminders-cli, calendar-cli, contacts-cli, mail-cli, sms-cli

Repos live at `~/dev/<tool>-cli/`. Each has its own DEVELOPMENT.md for tool-specific
conventions. This document captures the principles that span the whole suite.

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

**Fire-and-forget tools** — mail, sms
- One-way dispatch: you compose and send, you don't read back in this CLI
- No list, show, or inbox commands — those belong in the native app
- `find` in mail is the one exception: it provides context *before* composing, not after sending (current code still uses `search` — tracked as mail #12)

The test for whether a command belongs in a tool: *does it fit the tool's identity?*
A `mail inbox` command would be wrong not because it's hard, but because mail is a
send tool. Same reasoning cut `sms list` and `sms show`.

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

The failure mode: `phoneLabel()` in sms-cli always returned false, making the
mobile-number preference loop silently a no-op. The code looked like it was doing
something it wasn't. When a function can't be implemented correctly yet, remove
the call site too — don't leave the impression of working logic.

When features are removed, their supporting code goes with them. `resolveIdentifier()`
was written for `sms list` and `sms show`. When those commands were cut, the function
and its tests were deleted in the same commit.

---

## MCP is a suite-level project

The five MCP issues (reminders #4, calendar #8, contacts #6, mail #7, sms #5) are one
project, not five. A single MCP server exposes the whole suite to Claude. The value
compounds: Claude can add a reminder, send a confirmation email, and add the
recipient to a contact group — across tools, in one conversation.

Build it as a standalone `mcp-cli-suite` project that shells out to the installed
binaries. That way the CLIs stay clean and the MCP layer is independently deployable.

---

## Repo structure: 6 repos vs. monorepo

Current structure: one repo per tool (`reminders-cli`, `calendar-cli`, etc.) plus the umbrella `get-clear` repo that hosts GetClearKit.

**Why separate repos work:**
- Per-tool versioning, changelogs, and GitHub issues — clean signal per project
- Users can depend on one tool as a Swift package without pulling the others
- Releases are per-tool; the PKG installer tags specific versions
- PRs are scoped; changes to reminders don't appear in calendar history

**Why a monorepo would be better:**
- GetClearKit changes require push → wait for resolution → update each tool → push each tool. This propagation lag is the main pain point today
- Cross-cutting work (color pass, flag handling, date parsing migration) spans 5+ repos — hard to review as a unit, easy to leave one tool behind
- 5 `Package.swift` files to keep in sync; CI configured in 6 places
- Issues land in the wrong repo; cross-repo references are awkward

**Current verdict:** keep separate repos for now. The per-tool GitHub releases and issue tracking are worth more than the merge convenience at this stage. Revisit when GetClearKit churn settles down or when cross-cutting changes become the norm rather than the exception. Migrating is a one-time cost — rewriting git history, redirecting issue URLs, updating install scripts — so it's worth doing deliberately, not reactively.

---

## Architecture: the Lib/CLI split

Every tool has a pure `*Lib` target and a `*CLI` target.

`*Lib` — pure Swift, no framework imports, fully testable without permissions
`*CLI` — framework access (EventKit, Contacts, Security, URLSession), thin dispatch layer

The rule: if you want to write a test for something in `main.swift`, that's a signal
it belongs in the Lib. The boundary is enforced by not importing system frameworks
in the Lib target.

`TestRunner` is currently duplicated across all five test files. Extraction to a shared
package is tracked but not yet done — when it happens, all five benefit at once.

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

