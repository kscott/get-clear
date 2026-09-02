# Get Clear — Review Checklist

Read this before closing any issue. Start with the fast checklist — every item must pass. The sections below explain the rules behind each one.

---

## Before closing

- [ ] `swift test` — 0 failures
- [ ] Test coverage reviewed with Ken — run `swift test --enable-code-coverage` and report results; uncovered lines in Lib targets are a signal, not just a number. Code that resists coverage usually needs to move layers or get a better interface.
- [ ] `/simplify` run — reuse, quality, and efficiency pass complete; all findings addressed
- [ ] Boundary files: no `private func` whose signature contains no framework types (`EK*`, `CN*`, `JMAP*`) — see ARCHITECTURE.md
- [ ] Every new source file has a corresponding test file, committed in the same commit
- [ ] `main.swift` still under ~100 lines; no logic beyond dispatch
- [ ] No new flags added (only `--help`/`-h` and `--version`/`-v` are permitted in the entire suite)
- [ ] If output was touched: three-level color hierarchy observed; dot placement rules followed — see design.md
- [ ] If a command was added: its symmetric counterpart exists (`add` → `remove`, etc.)
- [ ] Pushed to remote before closing the issue

---

## Consistency across the suite

Things that must be the same in every tool:

- `rename` changes identity; `change` modifies attributes — distinct by design
- `setup` for first-time install + credentials (no separate `install` command)
- `help`, `--help`, `-h` all print usage and exit 0
- `--version`, `-v` print the version string and exit 0
- Errors go to stderr via `fail()`, exit non-zero
- No silent failures

---

## Don't ship dead code

Stub functions that can't be implemented honestly get deleted, not left in. When a function can't be implemented correctly yet, remove the call site too — don't leave the impression of working logic.

When features are removed, their supporting code goes with them. The function and its tests are deleted in the same commit.

---

## main.swift is dispatch-only

`main.swift` parses arguments, calls into Lib, and handles the process lifecycle. That is all. Business logic, formatting, protocol details, and validation do not belong there. A `main.swift` longer than ~100 lines is a signal something is wrong.

---

## Every file has one job

Before creating a file, write one sentence describing what it does. If you cannot, the design is not ready. The sentence becomes the file's header comment.

- `EventDateTime.swift` — Parses date/time strings into structured start/end/allDay values.
- `JMAPClient.swift` — Handles JMAP HTTP requests and responses.
- `ReminderFormatter.swift` — Formats reminder data for display output.

A file named `Helpers.swift` or `Utilities.swift` is a warning sign. If the job cannot be named, it has not been thought through.

---

## Prefer pure functions

A function that takes values and returns a value is testable by definition. Where framework objects require mutation (EventKit, CNContacts), keep the mutation thin and late. All decision logic — what to change, by how much, under what conditions — belongs in pure functions in the Lib.

---

## No duplication without a documented reason

If the same logic appears in two places, it belongs in GetClearKit or a shared Lib.

The allowed exception: when two things look the same but mean different things. Similarity is not duplication if the semantics differ. If keeping two implementations separate intentionally, say so in a comment.

---

## Test coverage ships with the code

New commands and new Lib functions ship with tests. Not in a follow-up issue. Tests are part of the definition of done.

Edge cases and bad input are first-class test cases:
- What happens when required arguments are missing?
- What happens when a string contains special characters?
- What happens when the user passes a value that looks valid but isn't?

---

## Tests are code — all rules apply

**One file, one job.** A test file tests one source file and nothing else.

**Test file structure mirrors source file structure.** For every file in `*Lib/`, there is a corresponding file in `Tests/*LibTests/`. New source file and test file ship in the same commit.

**Framework: Swift Testing.** Each file is `*Spec.swift`, one per source file, using `@Suite` / `@Test` / `#expect`. Run with `swift test` — no Xcode required.

**Structure: `@Suite` → nested `@Suite` → `@Test`.** One assertion per `@Test`. Descriptions are natural-English sentences. No two `@Test`s test the same behavior — pick the most readable example. Tests run in parallel; no shared mutable state, no ordering assumptions.

**Document absent behavior explicitly.** Unimplemented behavior gets a `@Test` that asserts the current (nil / empty) result and says "not yet supported" in its description. This makes the gap visible and provides a ready-made acceptance test.

---

## New code conforms to existing code

Before writing any new file, find and read its nearest equivalent elsewhere in the suite. The file structure, naming conventions, and internal patterns you find there are the standard, not suggestions. If something looks different from what already exists, that difference needs a reason. "I didn't look" is not a reason.
