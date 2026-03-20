# Feature Specification: Color Output Pass

**Feature Branch**: `003-color-output`
**Created**: 2026-03-14
**Status**: Shipped (2026-03-15, across all six repos)
**Input**: Five tools had inconsistent color handling — some checked `NO_COLOR`, none checked `isatty`. GetClearKit needed shared ANSI helpers, `fail()`, and flag dispatch so the logic wouldn't be duplicated across five codebases.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Visual Hierarchy in List Output (Priority: P1)

The user runs `reminders list`, `calendar week`, `contacts list`, or `contacts find` and can immediately parse the output. Names and titles draw the eye; dates, emails, phone labels, and calendar names recede. The structure of the output is visible at a glance, not inferred by reading every character.

**Why this priority**: The suite is used interactively every day. Color is the difference between output that reads instantly and output that requires careful scanning. This is the most frequently seen output in the suite.

**Independent Test**: Run `reminders list Ibotta`. Confirm reminder titles are bold and metadata (due date, list name) is dim. Pipe the output to `cat` — confirm all text is present, no ANSI codes appear.

**Acceptance Scenarios**:

1. **Given** a list of reminders, **When** the user runs `reminders list`, **Then** reminder titles are bold and due dates / metadata are dim.
2. **Given** a list of calendar events, **When** the user runs `calendar week`, **Then** event titles and day headers are bold and location is dim.
3. **Given** a contacts search, **When** the user runs `contacts find Ann`, **Then** contact names are bold and email/phone labels and secondary fields are dim.
4. **Given** `mail find` results, **When** the user runs the command, **Then** email subjects are bold and index numbers, dates, and senders are dim.
5. **Given** an SMS send confirmation, **When** the user runs `sms send`, **Then** the recipient name is bold and the phone or email address is dim.

---

### User Story 2 — Errors Are Impossible to Miss (Priority: P1)

The user or Claude runs a command with a bad argument — wrong list name, unknown contact, unrecognized command. The error appears in red with a clear "Error:" prefix on stderr, and the tool exits non-zero. There is no ambiguity about whether the command succeeded.

**Why this priority**: Claude acts on tool output. An error that looks like regular output causes Claude to proceed as if the command succeeded. Red + stderr + non-zero exit is the contract.

**Independent Test**: Run `reminders show "Nonexistent Reminder"`. Confirm the output reads "Error: ..." in red on stderr and the exit code is non-zero. Pipe stdout to `/dev/null` — confirm the error still appears.

**Acceptance Scenarios**:

1. **Given** a command that fails (bad argument, not found, permission denied), **When** the tool exits, **Then** a red "Error:" prefix appears on stderr and the exit code is 1.
2. **Given** output piped to another command, **When** an error occurs, **Then** the error still appears (on stderr, not swallowed by the pipe).
3. **Given** `NO_COLOR` is set, **When** an error occurs, **Then** the "Error:" prefix still appears but without color — the message is never suppressed, only the formatting.

---

### User Story 3 — Color Suppressed When Piped (Priority: P1)

The user pipes tool output to `grep`, `awk`, `pbcopy`, or any other command. The downstream tool receives clean text — no ANSI escape sequences. Scripts and Claude both receive content without noise.

**Why this priority**: ANSI codes in piped output corrupt the data. `grep "reminder title"` fails if the title is wrapped in escape sequences. This is a correctness requirement, not a preference.

**Independent Test**: Run `reminders list | cat`. Confirm no `\x1b[` sequences appear in the output. Run `reminders list > /tmp/out.txt && cat /tmp/out.txt` — confirm the file is clean text.

**Acceptance Scenarios**:

1. **Given** output piped to another command, **When** `isatty(STDOUT_FILENO)` returns 0, **Then** no ANSI codes appear in the output.
2. **Given** output redirected to a file, **When** the file is read, **Then** it contains plain text with no escape sequences.
3. **Given** `NO_COLOR` is set and stdout is a terminal, **When** any tool runs, **Then** color is suppressed — `NO_COLOR` is honored regardless of isatty.

---

### User Story 4 — Help and Version Flags Work Everywhere (Priority: P2)

The user runs `reminders --help`, `calendar version`, `sms -v`, or any flag variant across any tool. The tool responds correctly without needing per-tool duplicate logic for flag string comparison.

**Why this priority**: `--help` and `--version` are the outside world's expectations. Every tool must handle them. Centralizing the match logic prevents drift — a tool can't accidentally accept `--vers` or reject `-V` if the check is shared.

**Independent Test**: Run `reminders --help`, `reminders -h`, `reminders help`. All three should produce usage output. Run `calendar --version`, `calendar -v`, `calendar version`. All three should print the version string.

**Acceptance Scenarios**:

1. **Given** `--help`, `-h`, or bare `help` as the first argument, **When** any tool runs, **Then** usage output is shown.
2. **Given** `--version`, `-v`, or bare `version` as the first argument, **When** any tool runs, **Then** the version string is printed.
3. **Given** these flags on any of the five tools, **When** the tool runs, **Then** behavior is identical — no tool accepts a variant another rejects.

---

### Edge Cases

**The isatty bug**
Before this pass, reminders-cli and calendar-cli checked `NO_COLOR` but not `isatty`. Output piped to another command retained ANSI escape codes. contacts-cli was the first tool wired to GetClearKit and got the correct check from the start; the bug was diagnosed during that integration and filed as get-clear #10 for the other four tools. The fix was applied in the color pass commits.

**NO_COLOR takes precedence**
`ANSI.enabled` is a stored computed property — evaluated once at startup. Both conditions must be true for color to be active: `NO_COLOR` is absent AND stdout is a terminal. Either condition being false suppresses color. There is no way to re-enable color mid-process.

**Error output vs. color suppression**
`fail()` always prints to stderr. ANSI color suppression is based on stdout's isatty state, not stderr's. This means the red "Error:" prefix may be suppressed when stdout is piped even if stderr is a terminal. This is a known trade-off — the color state is determined once for the whole process, and the alternative (checking stderr separately) adds complexity for a rare case. The message is never suppressed; only the color may be.

**contacts-cli was first**
contacts-cli was wired to GetClearKit on 2026-03-14, the day GetClearKit was created. The other four tools had local inline ANSI helpers (with the isatty bug) that were replaced in two passes on 2026-03-15: the color pass (per-tool ANSI application) and the GetClearKit migration (replacing inline helpers with GetClearKit imports).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: All five tools MUST suppress ANSI color codes when `isatty(STDOUT_FILENO)` returns 0 (output is piped or redirected).
- **FR-002**: All five tools MUST suppress ANSI color codes when the `NO_COLOR` environment variable is set, regardless of terminal state.
- **FR-003**: The `ANSI.enabled` flag MUST be evaluated once at process startup as a stored computed property. It MUST NOT be re-evaluated per call.
- **FR-004**: Bold formatting (`ANSI.bold()`) MUST be applied to primary identifiers: reminder titles, event titles, contact names, email subjects, and recipient names on send confirmation.
- **FR-005**: Dim formatting (`ANSI.dim()`) MUST be applied to supporting detail: due dates, calendar names, locations, email addresses, phone numbers and labels, email senders, index numbers, and timestamps in find results.
- **FR-006**: Red formatting (`ANSI.red()`) MUST be used exclusively for errors — applied only to the "Error:" prefix in error output.
- **FR-007**: All error output MUST go to stderr. All normal output MUST go to stdout. Color formatting MUST NOT appear on stdout when output is piped.
- **FR-008**: `fail()` MUST print a red-prefixed "Error: <message>" to stderr and exit with code 1. It MUST be the single error output mechanism across all five tools — no tool may print errors via a separate code path.
- **FR-009**: `isVersionFlag()` MUST return true for `--version`, `-v`, and bare `version`. `isHelpFlag()` MUST return true for `--help`, `-h`, and bare `help`. Both MUST be used by all five tools for flag dispatch.
- **FR-010**: GetClearKit ANSI helpers, `fail()`, and flag helpers MUST live in the shared `GetClearKit` package (get-clear umbrella repo) and MUST NOT be duplicated in individual tool repos.
- **FR-011**: Tool repos MUST declare a dependency on `GetClearKit` via `Package.swift` pointing to the get-clear umbrella repo. Local inline ANSI helpers, `fail()`, and flag matching logic MUST be removed.

### Key Entities

- **`ANSI`**: Public enum in `GetClearKit/ANSI.swift`. Contains `enabled: Bool` (stored computed property), `bold(_ s: String) -> String`, `dim(_ s: String) -> String`, `red(_ s: String) -> String`. Suppresses output automatically; functions are identity functions when color is disabled.
- **`fail(_ msg: String) -> Never`**: Free function in `GetClearKit/Fail.swift`. Prints red "Error: \(msg)" to stderr, calls `exit(1)`. Declared `Never` — the compiler enforces that callers do not continue after calling it.
- **`isVersionFlag(_ s: String) -> Bool`**: Free function in `GetClearKit/Flags.swift`. Matches `--version`, `-v`, `version`.
- **`isHelpFlag(_ s: String) -> Bool`**: Free function in `GetClearKit/Flags.swift`. Matches `--help`, `-h`, `help`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All five tools produce zero ANSI escape sequences when output is piped to `cat` or redirected to a file.
- **SC-002**: All five tools produce zero ANSI escape sequences when `NO_COLOR` is set in the environment.
- **SC-003**: A user looking at any list, find, or show output in a terminal can identify the primary identifier (bold) without reading every token — it stands out visually.
- **SC-004**: An error from any tool produces a non-zero exit code and output on stderr. Redirecting stdout to `/dev/null` does not suppress the error.
- **SC-005**: No tool repo contains inline ANSI helper functions, a local `fail()` implementation, or manual flag string comparisons for `--help`/`--version` variants. All six repos pass this check post-migration.
- **SC-006**: Adding a new tool to the suite requires zero ANSI or error handling code in the new tool — importing GetClearKit is sufficient.

## Design Notes

**Three levels, not a palette.** The visual hierarchy has exactly three levels: bold (primary identifier), plain (body text), dim (metadata), with red reserved for errors. There is no fourth level, no accent color, no green for success. The constraint is intentional — adding levels would require a style guide; three levels can be applied by rule.

**`ANSI.red()` is an error color, not an emphasis color.** The temptation to use red for warnings, important notes, or urgent items is a trap. Red means "something went wrong" in every terminal convention the user has ever seen. Using it for anything other than errors would undermine the signal.

**`fail()` is `Never`.** Swift's `Never` return type means the compiler knows the function does not return. Callers don't need a `return` or `break` after it; the compiler enforces that they can't accidentally continue. This is the correct type for an error exit function.

**GetClearKit is the rule, not the exception.** The migration from inline helpers to GetClearKit is not just tidying. It establishes the pattern: shared behavior lives in GetClearKit. Any future tool that duplicates logic already in GetClearKit is wrong by definition — the rule is `GetClearKit` first, tool-specific only when the logic genuinely cannot be shared.

**contacts-cli was the reference implementation.** It was the first tool wired to GetClearKit and the one where the isatty bug was diagnosed. Its color application (bold names, dim labels and metadata, red errors) set the pattern followed by the other four tools in the March 15 pass.

**Ordering of the two March 15 passes.** The color pass commits (d729a6e, 47c62a7, 675fdba, b11805c) landed first, adding color with inline helpers but fixing the isatty bug. The GetClearKit migration commits (ed54784, 6890a3f, 2c1ff21, eeafa66) landed immediately after, replacing the inline helpers with GetClearKit imports. The two passes were made in immediate succession on the same afternoon.

## Assumptions

- Color state is binary — on or off for the whole process. There is no per-output-stream override.
- The suite targets macOS only. `STDOUT_FILENO` and `isatty()` are POSIX and available on all supported targets.
- `NO_COLOR` compliance follows https://no-color.org — presence of the variable (any value, including empty) disables color. Absence enables it (subject to isatty).
- Bold, dim, and red are universally supported by macOS Terminal, iTerm2, and any modern terminal emulator. No capability detection beyond isatty + NO_COLOR is required.
