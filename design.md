# Get Clear — Design

This document is the heart of the project. It captures why the vocabulary is what it is, why the tools are divided the way they are, and what good work looks like here.

`ARCHITECTURE.md` captures structural decisions. `CLAUDE.md` captures workflow. This captures ethos.

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

**Flags are a design failure, not a solution.**

The only flags in the entire suite are `--help`/`-h` and `--version`/`-v`, and those exist solely because the outside world expects them from any CLI. That is the complete list. There will be no others.

Every flag temptation is a command trying to be born. The flag is a shortcut around thinking. When you feel the pull toward a flag, stop — name what you're actually trying to express, and that name becomes the command.

```bash
# Wrong
mail send Alice subject "Lunch?" --draft

# Right — name the thing
mail draft Alice subject "Lunch?"
```

The test: would you say the flag word in conversation? *"Send this with dash-dash-draft"* — no. *"Save this as a draft"* — yes. When the word works in conversation, it works as a command.

**Common flag temptations and their answers:**

| Flag impulse | What it's really asking for |
|---|---|
| `--draft` | `mail draft` — a dedicated command |
| `--priority high` | `priority high` as a positional keyword (already works) |
| `--note "..."` | `note "..."` as a positional keyword (already works) |
| `--all` | Rethink the command — `--all` means the scope isn't named yet |
| `--calendar "Work"` | `calendar work week` — the scope is a keyword, not a flag |
| `--force` / `--yes` | Design the safety model into the tool, not the invocation |
| `--format` | The output format is determined by the command, not the caller |

**The history:** `--name` was the original flag in `edit`. The right answer turned out to be `rename` — a distinct command with its own semantic meaning that `--name` never had. The flag was a symptom of an incomplete design. Every flag in this suite's history has pointed to a missing command.

`--draft` in mail is the current open violation. It exists; it should not. The fix is `mail draft` as a first-class command.

When reviewing code: if a flag appears in a diff, stop. Ask what command the flag is trying to be. If you can't name it, the design isn't ready and the implementation shouldn't proceed.

**Natural language keywords** — accept conjugations people naturally type:
`repeat`/`repeating`/`repeats`, `note`/`notes`. Don't invent syntax when English works.

---

## Argument shape

Every command in the suite has the same shape. Three sentences:

1. The name comes first, quoted if it contains a space. A bare word that is also a keyword (`list`, `due`, …) needs quotes to be used as the name: `reminders add "list"`.
2. A due date is either bare right after the name or introduced by `due` (or `date`) anywhere — one or the other, never both. An optional `on` reads naturally in either form (`due on friday`, `on march 1`).
3. Everything else is `keyword value`, in any order. `note` / `body` / `message` comes last and takes the rest of the line.

```bash
reminders add "Pay rent" "march 1" list "Bills" repeat monthly priority high
reminders change "Pay rent" due none priority high
reminders rename "Pay rent" "Pay mortgage"
reminders add "Call dentist" due on friday note "ask about the crown"
contacts add "Bob Smith" email bob@x.com phone 555-1234
mail send "Alice Chen" subject "Lunch?" body "Free at noon?"
```

**Quoting.** Quote every value that contains a space. Quoting one that doesn't is harmless — a fully-quoted line parses identically — so when in doubt, quote. Use double quotes; if a value contains a literal `"` or `$`, single-quote that one argument.

The one place quotes are optional is the trailing text field (`note` / `body` / `message`): it takes the rest of the line, so `note ask about the crown` and `note "ask about the crown"` are the same. The examples above quote it anyway, for consistency.

**`list` is a keyword, not a position.** `reminders add "Pay rent" list "Bills"`, never `reminders add "Pay rent" Bills`. The bare form used to work only when the list already existed and silently became part of the date otherwise — a keyword removes the guesswork and the silent failure.

**Unrecognized input is an error.** A misspelled keyword, a stray word, a keyword with no value, a keyword twice, a date given both ways, a value that isn't valid for its field (an unknown priority, a sort key that isn't a real column, an unparseable date) — each stops the command with a message naming the problem. Nothing is silently absorbed or defaulted.

The parser is one shared implementation in GetClearKit, driven by a per-command descriptor. See `ARCHITECTURE.md`.

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

The person this is built for is busy, collaborative, juggling commitments to a lot of people. The vocabulary should feel like theirs — the words they'd use in conversation, not the words a form field would use.

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



