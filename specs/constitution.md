# Get Clear — Suite Constitution

Rules that apply to every tool, every feature, every spec. When a feature decision conflicts with this document, this document wins. When this document conflicts with `design.md`, update both — they must stay consistent.

---

## Tools handle what they can

A tool that surfaces a problem it cannot solve has failed. If the user has asked for something, the tool does it — or fails clearly — without handing work back to the user. The test: after the command runs, does the user have to do something they didn't expect to do?

The OS enforcing a security boundary (e.g., a password prompt in Installer.app) is not the tool abdicating responsibility. Everything up to that moment is the tool's job.

When designing a new feature: if the user would otherwise have to take a manual step, ask whether the tool can take it first.

---

## No flags

The only flags in the suite are `--help` / `-h` and `--version` / `-v`. They exist because the outside world expects them. Every other interaction is a subcommand or a natural language argument.

When you reach for a flag, stop. That is a signal to think harder. There is always a subcommand or argument that fits the vocabulary. `--name` → `rename`. `--draft` → `draft`.

---

## No silent failures

Every failure produces a message to stderr and exits non-zero. The user and Claude both need to know something went wrong. An empty exit is never acceptable.

---

## Stdout is for output. Stderr is for everything else.

Command results go to stdout. Errors, hints, and diagnostics go to stderr. When output is piped, ANSI codes are stripped — content is identical, presentation is not. Scripts must never receive noise.

---

## Add and remove ship together

Every command that creates a record must have a corresponding remove command in the same release. A mistake made by Claude must be undoable by Claude in the same tool. If remove doesn't exist, a mistake requires opening a native app to fix.

---

## Read-only commands never write

`list`, `find`, `show`, `open`, `what`, `recap`, `calendars`, `lists` — none of these write anything. Not to the log, not to data stores, not to the filesystem (except caches that are explicitly part of their design). If it reads, it reads only.

---

## The vocabulary is fixed

| Intent | Word |
|---|---|
| Create a record | `add` |
| Delete a record | `remove` |
| Modify attributes | `change` |
| Change identity (title, name) | `rename` |
| Search by content | `find` |
| Mark complete | `done` |
| Nothing recorded | `recorded` (not "logged", not "no activity") |

New commands must fit this vocabulary. If a new word is needed, it must pass the localization test: does the concept survive translation to French, Italian, and German? A word that only makes sense in English software UI is the wrong word.

---

## Setup is idempotent

`setup` commands are safe to re-run at any time. They detect existing state and reuse it. They prompt only when required. A user must never need to know or care whether this is their first run or their tenth.

---

## Internal commands are absent from usage()

Subcommands used only by the suite itself (e.g., `get-clear check-update`) are handled in the dispatch switch but never appear in `usage()` output. They are not documented. They require no access control — their behavior is harmless if discovered and run manually.

---

## Phoning home requires consent

Anything that sends data off the user's machine is off by default and requires explicit opt-in. Consent is requested once, during `get-clear setup`, as a single yes/no question, and written to `~/.config/get-clear/config.toml`. It is never asked again. The config file is the source of truth — this leaves the door open for a future toggle subcommand and a `get-clear settings` command to inspect and change values without re-running setup.

What may be collected, with consent: command usage counts, unrecognized command strings, error rates, and version in use. Unrecognized commands are the most important signal — repeated vocabulary misses indicate friction that the design should resolve. No personal content (titles, names, message bodies, contact details) is ever collected or transmitted. Data goes to a first-party endpoint under the developer's control.

The setup prompt must disclose what is collected before asking. Vague language ("help us improve") is not sufficient — the prompt must be specific.

---

## Color has exactly three levels

ANSI formatting in all tool output uses exactly three levels: **bold** for primary identifiers (titles, names, subjects), plain for body text, and **dim** for supporting metadata (dates, labels, addresses, indices). **Red is reserved exclusively for errors** — the "Error:" prefix in `fail()` output. It is never used for warnings, urgency, or emphasis.

Adding a fourth level requires a style guide. Three levels can be applied by rule. Red means "something went wrong" in every terminal convention — using it for anything else undermines the signal.

---

## GetClearKit first

Shared behavior lives in GetClearKit. If logic already exists in GetClearKit, duplicating it in a tool repo is wrong by definition. When writing new code in a tool repo, search GetClearKit first. When logic appears in two tool repos, it moves to GetClearKit before either ships.

The test: could a new sixth tool get this behavior by importing GetClearKit alone, with no copy-paste? If not, the wrong thing is in the wrong place.

---

## Timestamps come from the system clock

No timestamp may be supplied by a calling process. All times are generated at the moment of execution. This applies to log entries, cache writes, and any time-sensitive comparison.
