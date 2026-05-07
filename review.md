# Get Clear — Review Checklist

Read this before closing any issue. Every item applies to every change, regardless of size.

---

## Consistency across the suite

Things that must be the same in every tool:

- `rename` changes identity; `change` modifies attributes — distinct by design
- `setup` for first-time install + credentials (no separate `install` command)
- `help`, `--help`, `-h` all print usage and exit 0
- `--version`, `-v` print the version string and exit 0
- Errors go to stderr via `fail()`, exit non-zero
- No silent failures
- No flags except `--help`/`-h` and `--version`/`-v` — see design.md

---

## Don't ship dead code

Stub functions that can't be implemented honestly get deleted, not left in.

The failure mode: `phoneLabel()` in text-cli always returned false, making the mobile-number preference loop silently a no-op. The code looked like it was doing something it wasn't. When a function can't be implemented correctly yet, remove the call site too — don't leave the impression of working logic.

When features are removed, their supporting code goes with them. `resolveIdentifier()` was written for `text list` and `text show`. When those commands were cut, the function and its tests were deleted in the same commit.

---

## Engineering disciplines — inviolable

These are not guidelines. They apply to every line of code written in this project, by anyone, including Claude. When writing new code, check each one. When reviewing code, reject anything that violates them.

### main.swift is dispatch-only

`main.swift` parses arguments, calls into Lib, and handles the process lifecycle. That is all. Business logic, formatting, protocol details, and validation do not belong there. A `main.swift` longer than ~100 lines is a signal something is wrong.

If you are tempted to write logic in `main.swift` because it is quick or convenient, stop. Put it in the Lib. Quick and convenient is how the codebase got to 600-line main files that cannot be tested.

### Every file has one job

Before creating a file, write one sentence describing what it does. If you cannot, the design is not ready. The sentence becomes the file's header comment.

- `EventDateTime.swift` — Parses date/time strings into structured start/end/allDay values.
- `JMAPClient.swift` — Handles JMAP HTTP requests and responses.
- `ReminderFormatter.swift` — Formats reminder data for display output.

A file named `Helpers.swift` or `Utilities.swift` is a warning sign. Name things for what they are. If the job cannot be named, it has not been thought through.

### Design the interface before writing the implementation

Before moving or writing any function, define what it takes as input and what it returns. That contract is the design. If the contract is unclear, the implementation will be unclear too.

Write the test first. The test defines the contract. Then write the implementation that makes the test pass. This is not optional for logic that belongs in a Lib target.

### Moving code is not refactoring

A 600-line `main.swift` that becomes a 600-line `ToolLib.swift` is not progress. Refactoring means improving the design: clearer responsibilities, better interfaces, smaller functions, improved testability. The goal of an extraction is not to move lines — it is to produce a type or function with a clear contract that can be tested.

When extracting from `main.swift`, do not copy the inline structure. Redesign it.

### Prefer pure functions

A function that takes values and returns a value is testable by definition. A function that takes a mutable object and modifies it in place requires setting up state before testing and inspecting state after. Prefer the former wherever the framework allows.

Where framework objects require mutation (EventKit, CNContacts), keep the mutation thin and late. All decision logic — what to change, by how much, under what conditions — belongs in pure functions in the Lib.

### No duplication without a documented reason

If the same logic appears in two places, it belongs in GetClearKit or a shared Lib. The `what` command appearing identically in five `main.swift` files is the clearest example of what this rule prevents.

The allowed exception: when two things look the same but mean different things. Similarity is not duplication if the semantics differ. If you are keeping two implementations separate intentionally, say so in a comment.

### Test coverage ships with the code

New commands and new Lib functions ship with tests. Not in a follow-up issue. Not when there is time. Tests are part of the definition of done.

Edge cases and bad input are first-class test cases, not afterthoughts:
- What happens when required arguments are missing?
- What happens when a string contains special characters?
- What happens when the user passes a value that looks valid but isn't?

If a function is worth writing, the edge cases are worth testing.

### Tests are code — all rules apply

Every engineering discipline that applies to source files applies equally to test files. There are no exceptions for tests.

**One file, one job.** A test file named `ReminderFormatterTests.swift` tests `ReminderFormatter.swift` and nothing else. Stacking tests for multiple source files into a single file is the same violation as stacking multiple jobs into a single source file.

**Test file structure mirrors source file structure.** For every file in `*Lib/`, there is a corresponding file in `Tests/*LibTests/`. When a new source file is created, its test file is created in the same commit.

**Test framework is Quick + Nimble.** Each test file is a `QuickSpec` subclass named `*Spec.swift`. Run the suite with `swift test`. No custom harness, no `main.swift`.

**Structure: describe → context → it.** `describe` names the function or type under test. `context` names the scenario. `it` names one specific behavior. One assertion per `it`. Test descriptions are natural English sentences describing behavior — not restating the input. No two `it` blocks test the same behavior with different inputs; pick the most readable example.

**Document absent behavior explicitly.** When a feature is not yet implemented, add an `it` that asserts nil and includes "not yet supported" in the description. This makes the gap visible and gives the future implementation a ready-made acceptance test.

A test suite that cannot be described in one sentence is not ready to be written.

### New code conforms to existing code

Before writing any new file, find and read its nearest equivalent elsewhere in the suite. In a monorepo, that equivalent is always nearby. The file structure, naming conventions, and internal patterns you find there are not suggestions — they are the standard. A new `main.swift` that doesn't match the others isn't just inconsistent; it's wrong.

This applies to every layer: dispatch conventions in `main.swift`, handler naming, formatter structure, test file layout. If something looks different from what already exists, that difference needs a reason. "I didn't look" is not a reason.

### Flag code quality proactively

When writing or reviewing code in this project, apply these disciplines without being asked. If a function is growing too large, say so. If logic belongs in a Lib and is being written in `main.swift`, say so. If a pattern is being duplicated, say so.

Do not wait to be asked if the code is good. The expectation is that every change leaves the codebase in better shape than it found it.
