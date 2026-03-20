# Feature Specification: Activity Log, What, and Recap

**Feature Branch**: `001-activity-log`
**Created**: 2026-03-18
**Status**: Shipped (2026-03-19, branch `001-activity-log`)
**Input**: User description: "Activity log and done report: every write command across all five tools logs a timestamped entry to a daily log file. The what command surfaces the log per-tool and suite-wide. Reminders done report shows completions over time."

## User Scenarios & Testing *(mandatory)*

### User Story 1 — See Everything I Did (Priority: P1)

The user runs `get-clear what` and gets a complete, timestamped, chronological list of every write action taken across all five tools — reminders added and completed, events added, contacts updated, messages and emails sent. This is the raw log: accurate, complete, uninterpreted. Good for filling a timesheet, scanning what happened, or feeding to Claude for further analysis.

Time range defaults to today but accepts specifiers: `get-clear what yesterday`, `get-clear what this week`, `get-clear what last week`, or any date range supported by GetClearKit's range parser.

**Why this priority**: This is the foundation. Every other story depends on the log existing and being complete. Raw log output delivers immediate value with no interpretation required.

**Independent Test**: Use all five tools to take at least one write action each. Run `get-clear what` and confirm every action appears with a timestamp and the tool that produced it.

**Acceptance Scenarios**:

1. **Given** the user has added a reminder and sent an SMS today, **When** they run `get-clear what`, **Then** both actions appear in chronological order with timestamps and the tool name.
2. **Given** no write actions have been taken today, **When** they run `get-clear what`, **Then** the output says "Nothing recorded so far today." (not an error).
3. **Given** actions on two different days, **When** they run `get-clear what this week`, **Then** all actions from the current week appear grouped or labeled by date.
4. **Given** actions across multiple days, **When** they run `get-clear what yesterday`, **Then** only yesterday's actions appear.

---

### User Story 2 — See What a Single Tool Did Today (Priority: P2)

The user wants to review what reminders were touched today, or what calendar events were added this week, without seeing the full cross-tool log.

**Why this priority**: Focused review per tool is the natural follow-on to the suite-wide view. Useful when handing off or reviewing a specific area of work.

**Independent Test**: Add a reminder and a contact. Run `reminders what` — confirm only the reminder action appears.

**Acceptance Scenarios**:

1. **Given** actions in both reminders and calendar, **When** they run `reminders what`, **Then** only reminder actions appear.
2. **Given** no actions in calendar today, **When** they run `calendar what`, **Then** the output says nothing was recorded in this tool today (not an error).

---

### User Story 3 — Get a Recap (Priority: P3)

The user runs `get-clear recap` at any point in the day — morning, midday, end of day — and gets a structured, human-readable summary of where they've shown up so far. Not a raw log, but an interpreted view: commitments kept, things moved forward, the shape of the day. Satisfying to read on its own at the CLI, and exactly what Claude needs to compose a narrative when asked "how's my day going?"

`recap` is not a finalizing action — it can be run any number of times. Run it midday for a pick-me-up. Run it before a 1:1 to remember what you've shipped. Run it at end of day to feel the weight of what got done. The output reflects what has happened so far, not what was planned.

`recap` accepts the same time range specifiers as `what` (default: today; also `yesterday`, `this week`, `last week`, date ranges).

The recap draws from four sources:
- **Reminders `done`** — task commitments explicitly closed out
- **Mail sent** — communication commitments fulfilled (the send is the done)
- **SMS sent** — same; a quick message kept a relationship or resolved a thread
- **Calendar events that occurred** — time commitments honored; queried from the calendar, not the log

When a meeting is processed with Claude afterward ("I had the meeting, here are the notes"), the resulting reminders and follow-ups appear in the recap through their own tools — the meeting and its follow-through visible together. Contacts updated in the process appear in `what` but not `recap` — they are context for the commitment, not the commitment itself.

**Why this priority**: The recap answers a different question than `what`. Not "what happened?" but "where did I show up?" That reframe — from activity to character — is what makes it motivating.

**Independent Test**: Complete a reminder, send an email, and have a calendar event pass. Run `get-clear recap` mid-afternoon. Confirm the output is structured by commitment type, reads as a meaningful summary, and excludes scaffolding activity (adds, changes).

**Acceptance Scenarios**:

1. **Given** a reminder marked done, an email sent, and an SMS sent today, **When** they run `get-clear recap`, **Then** all three appear as commitments kept — structured by type, not as a raw list.
2. **Given** reminders added but not completed, **When** they run `get-clear recap`, **Then** the adds do not appear — only `done` actions count as commitments kept.
3. **Given** a calendar event whose end time has passed, **When** they run `get-clear recap`, **Then** the event appears as a kept time commitment.
4. **Given** a busy morning with 10 actions, **When** the user runs `get-clear recap` at noon, **Then** the output reflects only what has happened so far — not the full day, not a projection.
5. **Given** `get-clear recap this week`, **When** they run it, **Then** commitments kept appear across all days in range with no gaps from missed sessions.

---

### User Story 4 — Log Survives Across Sessions (Priority: P4)

The user uses Get Clear tools throughout the day in different Claude conversations. When they ask for a summary at the end of the day, all actions from all sessions are present in the log — not just the current session.

**Why this priority**: Without persistence across sessions, the log is nearly useless. Every session would only show its own activity.

**Independent Test**: In two separate terminal sessions (simulating two Claude conversations), each perform one write action. Run `get-clear what` in a third session and confirm both actions appear.

**Acceptance Scenarios**:

1. **Given** write actions in two separate sessions on the same day, **When** `get-clear what` runs in a third session, **Then** all actions are present in the output.
2. **Given** a log entry written at 11:55pm, **When** reviewed the next morning with `get-clear what`, **Then** the previous day's entry does not appear in today's output.

---

### Edge Cases

**The midnight failure case**
A user works a full day, closes out at 11:52pm, runs `get-clear recap` at 12:05am to feel the weight of what they accomplished. The clock has crossed midnight. Today's log file is empty. Without a recency rule, the tool returns "Quiet so far. Ready for the next thing." — the opposite of what it promises. This is not a minor UX miss. It is the tool failing at the moment it matters most.

**Recency rule (FR-018):** If today has no log entries, check the most recent log entry across all files. If it was written within 3 hours of now, show that day's entries instead — the user is still in their session. The date header makes the substitution transparent. If the last entry was more than 3 hours ago, treat today as a fresh start. No configuration required — the log knows the rhythm.

**Log mechanics**
- What happens if the log directory does not exist yet (first run)?
- What happens if the log file is unreadable or corrupted?
- What happens if a write command fails — does it still log?
- What does the output look like for a very active day (50+ actions)?
- What if two write commands run in very quick succession — do both appear?
- What happens when a record is added and later removed within the same query range — does it appear in recap? **Non-issue:** recap queries live data stores for reminders and calendar. A cancelled reminder isn't completed; a removed calendar event isn't in EventKit. The data stores handle this naturally — no suppression logic required.

**Calendar: `what` vs. `recap`**
- `calendar what` shows write actions through the CLI — events added or removed. An event that occurred today does not appear in `calendar what` unless it was also added or modified today via the tool. These are different questions: "what did I do to my calendar?" vs. "what happened on my calendar?"
- `recap`'s calendar contribution is queried from the calendar directly (not from the write log), so it captures occurrences regardless of whether the CLI was used to create them.

**All-day events in `recap`**
- Timed events use end time to determine whether they have occurred (end time is in the past).
- All-day events MUST use date comparison, not end-time comparison. EventKit sets all-day event end times to midnight of the following day — a strict end-time check at 6pm would exclude a conference that ran all day. An all-day event is considered "occurred" if its calendar date falls within the query range.
- An all-day event that is a deadline marker (e.g., "Project due") has occurred in the calendar sense, but whether the underlying commitment was met is reflected in reminders — not in the calendar event itself.
- "Out of office" or vacation blocks appear as calendar events and will surface in `recap`. This is acceptable — they represent a time commitment to yourself and others.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Every successful write command in all five tools (`add`, `remove`, `change`, `rename`, `done`, `send`) MUST write a timestamped log entry at the time the action completes.
- **FR-002**: Read-only commands (`list`, `find`, `show`, `open`, `what`, `recap`, `calendars`, `lists`) MUST NOT write log entries.
- **FR-003**: Each log entry MUST record: timestamp (date and time), tool name, command name, a human-readable description of the record acted on (e.g., reminder title, event title, contact name, recipient), and — where the tool has a native container — the container name (reminders list, calendar name). Container name is the project signal: a reminder in "Trinity Council" is a Trinity Council task with no tagging required.
- **FR-004**: Log entries MUST be written to a daily log file organized by date, so all of today's actions are retrievable from a single location.
- **FR-005**: The `what` command MUST be available in all five tools and in a suite-level `get-clear what` entry point. `recap` is suite-level only — it exists as `get-clear recap` and has no per-tool variant. The value of `recap` is the full picture across all tools; a per-tool recap would be too narrow to be meaningful.
- **FR-006**: `<tool> what` MUST display all log entries for that tool from today, in chronological order.
- **FR-007**: `get-clear what` MUST display all log entries across all five tools from today, in chronological order.
- **FR-008**: Both `<tool> what` and `get-clear what` MUST accept an optional time range argument (default: today; also supports `yesterday`, `this week`, `last week`, named days, and date ranges).
- **FR-009**: `get-clear recap` MUST display a structured, human-readable summary of commitments kept — grouped by type (from your calendar, tasks completed, sent) — for the given time range (default: today). It MUST be runnable at any point in the day and always reflect activity so far, not a full-day projection.
- **FR-009a**: `get-clear recap` MUST draw from four sources: reminders completed within the time range (queried from the Reminders database via `EKReminder.completionDate` — not from the log), mail `send` commands (from the log), SMS `send` commands (from the log), and past calendar events queried from the calendar at report time. Reminders are queried live for the same reason as calendar events: a commitment kept is a commitment kept regardless of which interface completed it. Mail and SMS remain log-only — no equivalent live query source exists for those. What constitutes "past" for calendar events follows FR-015: end-time comparison for timed events, date comparison for all-day events.
- **FR-009b**: `get-clear recap` MUST accept the same time range specifiers as `what` (default: today; also `yesterday`, `this week`, `last week`, named days, date ranges).
- **FR-009c**: `get-clear recap` output MUST be meaningful and satisfying to read at the CLI without Claude, and MUST also serve as useful structured input when Claude is asked to narrate or interpret the day.
- **FR-009d**: `get-clear recap` MUST display a timespan derived from the first and last log entry timestamps of the requested period, rounded to the nearest 15 minutes — e.g., "9:00am → 4:45pm". Exact timestamps MUST NOT be shown. Rounding is intentional: it signals that the tool has not captured everything, and sets honest expectations about what the timespan represents. If only one log entry exists, display its rounded timestamp with no end. If no log entries exist, no timespan is shown.
- **FR-010**: If no log entries exist for the requested range, the output MUST differ based on whether the range is today or a past period:
  - **Today — `recap`**: displays an encouraging message that holds the door open — no mention of absence, just the opportunity remaining. Exact phrasing: *"Quiet so far. Ready for the next thing."*
  - **Today — `what` and `<tool> what`**: plain but not alarming — "Nothing recorded so far today." Per-tool variant: "Nothing recorded in reminders today." (or whichever tool.) Behavior is identical to suite `what`, filtered to the tool.
  - **Past ranges — all commands**: plain and factual — "Nothing recorded yesterday." / "Nothing recorded this week." No encouragement; that door is closed.
  - Empty output with no message is never acceptable.
- **FR-011**: Log entries MUST be written immediately when an action completes — not buffered or deferred to session end.
- **FR-012**: Failed commands (those that exit with an error) MUST NOT write a log entry — only successful actions are recorded.
- **FR-013**: The log storage location MUST be consistent and predictable so the suite-level `get-clear what` can aggregate from a single known location without tool-specific configuration.
- **FR-014**: The log directory MUST be created automatically on first use — no manual setup required.
- **FR-015**: When querying past calendar events for `recap`, timed events MUST use end-time comparison; all-day events MUST use date comparison. An all-day event is "occurred" if its calendar date falls within the query range, regardless of whether its exact end timestamp has passed.
- **FR-018**: When today has no log entries, `what` and `recap` MUST check the most recent log entry across all files. If that entry was written within 3 hours of now, display that day's entries instead — the user is still in their session. The date header must reflect the actual date of the entries shown, making the substitution transparent. If the most recent entry is more than 3 hours old, treat today as a fresh start and apply the normal empty state.
- **FR-016**: All timestamps MUST be generated from the system clock at the moment of command execution. No timestamp may be supplied by the calling process (e.g., Claude). This applies to log entry timestamps and to the "current time" used when evaluating which calendar events have occurred.
- ~~**FR-017**~~: *(removed)* Add/remove suppression is no longer needed. Recap queries live data stores for reminders and calendar — a cancelled reminder isn't completed, a removed event isn't in EventKit. The data stores enforce this naturally. Mail and SMS are log-sourced but have no remove equivalent.

### Key Entities

- **Log Entry**: A single recorded action. Attributes: timestamp, tool name, command name, human-readable description of the record acted on, container name where applicable (reminders list, calendar name).
- **Daily Log File**: The file containing all entries for a given calendar day. One file per day; all tools contribute to the same shared location.
- **Recap**: The suite-level view of commitments kept: reminders marked `done`, mail sent, SMS sent, and calendar events that have occurred. The first three come from the write log; past calendar events are queried from the calendar at report time. Suite-level only — no per-tool variant. Queryable by time range.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every successful write action across all five tools produces a log entry within the same second the action completes.
- **SC-002**: `get-clear what` with no arguments returns all of today's entries in under one second, regardless of how many tools were used.
- **SC-003**: A user can answer "what did I do today?" without opening any app or recalling which session they used — `what` is the complete record of actions across all tools and sessions.
- **SC-004**: A user can answer "where did I keep my commitments this week?" with a single command and a time range argument — covering task completions, messages sent, and meetings attended — with no gaps caused by missed sessions.
- **SC-005**: Log entries are written in plain language a non-technical user can understand without knowing the tool's internal syntax.
- **SC-006**: The `what` command is consistent enough across all five tools that a user who knows `reminders what` can correctly use `calendar what` without reading documentation.
- **SC-007**: `get-clear recap` output reads as progress, not a ledger. The tone is affirmative — it surfaces what was done in a way that feels like a shoulder tap, not an audit. A user who runs it mid-afternoon should feel the weight of what they've already accomplished. Output is tight: every word earns its place. Do the extra work to make things shorter.

## Design Notes

**Contacts are not part of recap — by design.** A contact is not a commitment; it is who the commitment is regarding. Adding or updating a contact is infrastructure: it makes future commitments possible but is not itself a kept commitment. Contacts appear in `what` (complete action record) but have no place in `recap` (commitments kept). This is not an oversight.

**`what` and `recap` are MCP-ready.** Both commands are designed to serve two consumers equally: a person reading output directly at the CLI, and Claude calling the command via MCP to compose a narrative or answer a question. `recap` output is structured exactly for this — grouped by commitment type, tightly worded, no filler. When the MCP server is built (get-clear #3), `get-clear what` and `get-clear recap` should be exposed as tools. "How's my day going?" is an MCP call to `recap` followed by Claude narrating the result.

**Lists as projects — no tags needed.** Reminders lists and calendar names are the project attribution layer. A reminder's list name is captured in the log entry and surfaces in `what` and `recap` output — no separate tagging system required. Calendar attribution is coarser ("Work", "Personal") but event titles carry meaning on their own, and Claude can make project associations from them when asked. The practical guidance: if project context matters for a type of work, use a more specific list rather than reaching for a tag.

**The tag boundary.** This is not a tagging system. Log entries do not accept user-supplied tags or labels at write time. Project context comes from structure that already exists (lists, calendars) or from content that already has meaning (titles, recipients). Any future pressure toward tags should be resolved by making list structure more specific instead.

## Assumptions

- The log is local to the current machine. Cross-machine aggregation is out of scope.
- The `get-clear` suite-level entry point is a new binary or script in the umbrella repo; its exact form is a planning-phase decision.
- Log file retention is out of scope for v1 — files accumulate until the user cleans them up.
- `recap` is a structured view over the shared log (plus a live calendar query), not a separate data store.
- Time range parsing for `what` and `recap` is handled by GetClearKit's range parser. It is broad and accepting — natural language, forgiving of variations, erring toward inclusion. The spec does not enumerate specific formats; the parser is the authority on what it accepts.
- The log records successful completions only; it is not a debug or audit trail.
