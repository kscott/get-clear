# CLI Command Contracts

## Per-tool: `<tool> what [range]`

Available in all five tools. Displays all log entries for that tool in the requested range.

```
reminders what
reminders what yesterday
reminders what this week
calendar what last week
```

**Output format**: Chronological list, one entry per line. Each line: timestamp · command · description · container (if present).

**Date header rule**: Today queries show no date header — the date is implicit, you're living in it. Any other range (yesterday, a specific past date, this week, last week) shows a date header, even for a single past day. Without a header, a past timestamp floats in time.

Today:
```
 2:32pm  done   Call Sarah  [Ibotta]
 3:15pm  add    Review PR   [Ibotta]
 4:01pm  done   Review PR   [Ibotta]
```

Yesterday (or any past single day):
```
Tuesday March 18

 2:32pm  done   Call Sarah  [Ibotta]
 3:15pm  add    Review PR   [Ibotta]
 4:01pm  done   Review PR   [Ibotta]
```

**Empty state (today)**: `Nothing logged in reminders today.`
**Empty state (past)**: `Nothing logged in reminders yesterday.` (or appropriate range)

---

## Suite-level: `get-clear what [range]`

Aggregates log entries across all five tools for the requested range.

```
get-clear what
get-clear what yesterday
get-clear what this week
get-clear what last week
```

**Output format**: Same as per-tool but includes tool name column. Same date header rule applies — no header for today, header for any other range.

Today:
```
 2:32pm  reminders  done   Call Sarah       [Ibotta]
 3:15pm  reminders  add    Review PR        [Ibotta]
 4:47pm  mail       send   Alex Re: notes
```

Yesterday (or any past range):
```
Tuesday March 18

 2:32pm  reminders  done   Call Sarah       [Ibotta]
 3:15pm  reminders  add    Review PR        [Ibotta]
 4:47pm  mail       send   Alex Re: notes

Wednesday March 19

 9:15am  reminders  add    Team standup prep  [Ibotta]
```

**Empty state (today)**: `Nothing logged so far today.` — unless the most recent log entry across all files was within 3 hours, in which case that day's entries are shown instead (FR-018).
**Empty state (past)**: `Nothing logged yesterday.`

---

## Suite-level: `get-clear recap [range]`

Commitments-kept summary. Suite-level only — no per-tool variant.

```
get-clear recap
get-clear recap yesterday
get-clear recap this week
get-clear recap last week
```

**Output format**: Grouped by commitment type, with timespan header.

```
Wednesday March 19 · 9:00am → 4:45pm

  From your calendar   Sprint review · Trinity Council prep
  Tasks completed      Call Sarah [Ibotta] · Review PR [Ibotta]
  Sent                 Email to Alex · Text to Shaun Boyd
```

Groups are omitted when empty. If all groups are empty:
- Today: `Quiet so far. Ready for the next thing.` (no timespan shown) — unless the most recent log entry was within 3 hours, in which case that day's recap is shown instead (FR-018).
- Past range: `Nothing logged yesterday.`

**Suppression**: Records added and removed within the range do not appear in any group.

---

## Log Entry Write (internal — not a user-facing command)

Called by each tool's Lib after every successful write command.

```swift
// GetClearKit public API
ActivityLog.write(
    tool: "reminders",
    cmd: "done",
    desc: "Call Sarah",
    container: "Ibotta"  // nil for mail, sms
)
```

Writes one JSON Lines entry to `~/.local/share/get-clear/log/YYYY-MM-DD.log` using POSIX `O_APPEND`. Creates directory and file if they don't exist. On failure: silently drops the entry — log write failure MUST NOT cause the tool command to fail.
