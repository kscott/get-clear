# Feature Specification: Activity Log and Done Report

**Feature Branch**: `001-activity-log`
**Created**: 2026-03-18
**Status**: Draft
**Input**: User description: "Activity log and done report: every write command across all five tools logs a timestamped entry to a daily log file. The what command surfaces the log per-tool and suite-wide. Reminders done report shows completions over time."

## User Scenarios & Testing *(mandatory)*

### User Story 1 — See What I Got Done Today (Priority: P1)

At the end of a busy day, the user asks Claude "what did I get done today?" Claude runs `get-clear what` and returns a complete, timestamped list of every action taken across all five tools that day — reminders added and completed, events added, contacts updated, messages and emails sent.

**Why this priority**: This is the core feedback loop. Every other story builds on the log existing and being queryable. It delivers immediate value with no UI beyond the command itself.

**Independent Test**: Use all five tools to take at least one write action each. Then run `get-clear what` and confirm every action appears with a timestamp and the tool that produced it.

**Acceptance Scenarios**:

1. **Given** the user has added a reminder and sent an SMS today, **When** they run `get-clear what`, **Then** both actions appear in chronological order with timestamps and the tool name.
2. **Given** no write actions have been taken today, **When** they run `get-clear what`, **Then** the output says no activity today (not an error).
3. **Given** actions on two different days, **When** they run `get-clear what`, **Then** only today's actions appear.

---

### User Story 2 — See What a Single Tool Did Today (Priority: P2)

The user wants to review what reminders were touched today, or what calendar events were added this week, without seeing the full cross-tool log.

**Why this priority**: Focused review per tool is the natural follow-on to the suite-wide view. Useful when handing off or reviewing a specific area of work.

**Independent Test**: Add a reminder and a contact. Run `reminders what` — confirm only the reminder action appears.

**Acceptance Scenarios**:

1. **Given** actions in both reminders and calendar, **When** they run `reminders what`, **Then** only reminder actions appear.
2. **Given** no actions in calendar today, **When** they run `calendar what`, **Then** the output says no activity today in this tool (not an error).

---

### User Story 3 — Where Did I Keep My Commitments Today (Priority: P3)

The user asks "where did I keep my commitments today?" and gets a focused view of follow-through — not all activity, but specifically the moments of fulfillment: tasks completed, messages sent, meetings attended. This is the done report: evidence of character over time.

The done report draws from four sources:
- **Reminders `done`** — task commitments explicitly closed out
- **Mail sent** — communication commitments fulfilled (the send is the done; it may have resolved something that never needed a reminder)
- **SMS sent** — same; a quick message kept a relationship or resolved a thread
- **Calendar events that occurred** — time commitments honored; past events are queried automatically, no explicit close action required

When a meeting ends and the user processes it with Claude ("I had the meeting, here are the notes"), the resulting reminders added, contacts updated, and follow-ups set also appear in the done report through their own tools. The meeting and its follow-through are both visible.

**Why this priority**: The done report is more motivating than the daily log because it shows follow-through, not just activity. It answers a different question: not "what happened?" but "where did I show up?"

**Independent Test**: Complete a reminder, send an email, and have a calendar event pass. Run the done report and confirm all three appear under their respective categories.

**Acceptance Scenarios**:

1. **Given** a reminder marked done, an email sent, and an SMS sent today, **When** they run the done report, **Then** all three appear as commitments kept — grouped or labeled by type.
2. **Given** reminders added but not completed, **When** they run the done report, **Then** the adds do not appear — only the `done` actions.
3. **Given** a calendar event whose end time has passed, **When** they run the done report, **Then** the event appears as a kept time commitment — queried from the calendar, not from the write log.
4. **Given** the done report for the week, **When** they run it, **Then** completions, sends, and past events appear across all days in range — with no gaps from missed sessions.
5. **Given** a meeting processed with Claude after it ended ("I had the meeting, here are the notes"), **When** they run the done report, **Then** both the past calendar event and the follow-up reminders or contacts changes appear.

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

**Log mechanics**
- What happens if the log directory does not exist yet (first run)?
- What happens if the log file is unreadable or corrupted?
- What happens if a write command fails — does it still log?
- What does the output look like for a very active day (50+ actions)?
- What if two write commands run in very quick succession — do both appear?
- What happens when a reminder is added and then immediately removed — do both events appear?

**Calendar: `what` vs. done report**
- `calendar what` shows write actions through the CLI — events added or removed. An event that occurred today does not appear in `calendar what` unless it was also added or modified today via the tool. These are different questions: "what did I do to my calendar?" vs. "what happened on my calendar?"
- The done report's calendar contribution is queried from the calendar directly (not from the write log), so it captures occurrences regardless of whether the CLI was used to create them.

**All-day events in the done report**
- Timed events use end time to determine whether they have occurred (end time is in the past).
- All-day events MUST use date comparison, not end-time comparison. EventKit sets all-day event end times to midnight of the following day — a strict end-time check at 6pm would exclude a conference that ran all day. An all-day event is considered "occurred" if its calendar date falls within the query range.
- An all-day event that is a deadline marker (e.g., "Project due") has occurred in the calendar sense, but whether the underlying commitment was met is reflected in reminders — not in the calendar event itself.
- "Out of office" or vacation blocks appear as calendar events and will surface in the done report. This is acceptable — they represent a time commitment to yourself and others.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Every successful write command in all five tools (`add`, `remove`, `change`, `rename`, `done`, `send`) MUST write a timestamped log entry at the time the action completes.
- **FR-002**: Read-only commands (`list`, `find`, `show`, `open`, `what`, `calendars`, `lists`) MUST NOT write log entries.
- **FR-003**: Each log entry MUST record: timestamp (date and time), tool name, command name, and a human-readable description of the record acted on (e.g., reminder title, event title, contact name, recipient).
- **FR-004**: Log entries MUST be written to a daily log file organized by date, so all of today's actions are retrievable from a single location.
- **FR-005**: The `what` command MUST be available in all five tools and in a suite-level `get-clear what` entry point.
- **FR-006**: `<tool> what` MUST display all log entries for that tool from today, in chronological order.
- **FR-007**: `get-clear what` MUST display all log entries across all five tools from today, in chronological order.
- **FR-008**: Both `<tool> what` and `get-clear what` MUST accept an optional time range argument (default: today; also supports `week`, `yesterday`, named days, and date ranges).
- **FR-009**: The done report MUST draw from four sources: reminders `done` commands (from the log), mail `send` commands (from the log), SMS `send` commands (from the log), and calendar events whose end time has passed (queried from the calendar at report time — not from the write log).
- **FR-010**: If no log entries exist for the requested range, the command MUST output a message indicating no activity — not an error or empty screen.
- **FR-011**: Log entries MUST be written immediately when an action completes — not buffered or deferred to session end.
- **FR-012**: Failed commands (those that exit with an error) MUST NOT write a log entry — only successful actions are recorded.
- **FR-013**: The log storage location MUST be consistent and predictable so the suite-level `get-clear what` can aggregate from a single known location without tool-specific configuration.
- **FR-014**: The log directory MUST be created automatically on first use — no manual setup required.
- **FR-015**: When querying past calendar events for the done report, timed events MUST use end-time comparison; all-day events MUST use date comparison. An all-day event is "occurred" if its calendar date falls within the query range, regardless of whether its exact end timestamp has passed.

### Key Entities

- **Log Entry**: A single recorded action. Attributes: timestamp, tool name, command name, human-readable description of the record acted on.
- **Daily Log File**: The file containing all entries for a given calendar day. One file per day; all tools contribute to the same shared location.
- **Done Report**: A cross-tool view of commitments kept: reminders marked `done`, mail sent, SMS sent, and calendar events that have occurred. The first three come from the write log; past calendar events are queried from the calendar at report time. Queryable by time range.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every successful write action across all five tools produces a log entry within the same second the action completes.
- **SC-002**: `get-clear what` with no arguments returns all of today's entries in under one second, regardless of how many tools were used.
- **SC-003**: A user can answer "what did I get done today?" without opening any app or recalling which session they used — the log is the complete record.
- **SC-004**: A user can answer "where did I keep my commitments this week?" with a single command and a time range argument — covering task completions, messages sent, and meetings attended — with no gaps caused by missed sessions.
- **SC-005**: Log entries are written in plain language a non-technical user can understand without knowing the tool's internal syntax.
- **SC-006**: The `what` command is consistent enough across all five tools that a user who knows `reminders what` can correctly use `calendar what` without reading documentation.

## Assumptions

- The log is local to the current machine. Cross-machine aggregation is out of scope.
- The `get-clear` suite-level entry point is a new binary or script in the umbrella repo; its exact form is a planning-phase decision.
- Log file retention is out of scope for v1 — files accumulate until the user cleans them up.
- The done report is a filtered view of the shared log, not a separate data store.
- Time range syntax for `what` reuses existing range parsing already in GetClearKit (`today`, `week`, `yesterday`, `monday`, date ranges).
- The log records successful completions only; it is not a debug or audit trail.
