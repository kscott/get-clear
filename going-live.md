# Get Clear — Going Live

---

## Completed ✅

| Item | Shipped |
|---|---|
| PKG signed, notarized, stapled | 2026-03-14 |
| README.md + why.md | 2026-03-27 |
| Activity log, `what`, `recap` | 2026-03-19 |
| Color output, shared fail(), date parsing, flag handling | 2026-03-15 |
| Shell completions | 2026-03-15 |
| calendar setup | 2026-03-15 |
| Update notifier | 2026-03-19 |
| `--help` flag guard | 2026-04-10 |
| Installer HTML fixes (sms→text, encoding, setup instructions) | 2026-04-10 |

---

## Blockers — ordered by dependency

Nothing ships until all of these are done. Order matters.

### 1. Extract business logic from main.swift — #35, #36, #37, #38, #39
**Do this first, one tool at a time. No cross-repo dependency.**

Each tool's main.swift contains business logic, formatting, and protocol details that cannot be unit tested. Each extraction produces focused, single-responsibility files with designed interfaces — not a mass move. Design the interface first. Write the test. Then write the code. See individual issues for interface designs and definition of done.

| Issue | Tool | Key extractions |
|---|---|---|
| #35 | reminders | RecurrenceConversion, ReminderFormatter, ChangeCommand |
| #36 | calendar | EventDateTime (61-line parser, zero tests), EventFormatter, CalendarResolver |
| #37 | contacts | ChangeCommand, ContactStore, ContactFormatter |
| #38 | mail | MailConfiguration, JMAPClient, MailFormatter, SetupCommand, SendCommand |
| #39 | text | MessagesClient (appleScriptLiteral — security-relevant, zero tests) |

**#38 must come before #14 (Gmail).** Once JMAP logic is in JMAPClient, Gmail is a parallel OAuth2 implementation. Without the extraction, Gmail forks main.swift.

**#36 must come before calendar #15 (`calendar change`).** The implementation belongs in CalendarLib alongside EventFormatter and CalendarResolver — not in main.swift.

**Unblocks:** #14, calendar #15, #40, #41–45.

---

### 2. `calendar change` — calendar #15
**Depends on:** #36 (EventFormatter and CalendarResolver extracted into CalendarLib)

Modifying events is expected functionality. Runs SpecKit first; implementation lands in CalendarLib alongside the other extracted types from #36.

---

### 3. Move reminder to list — reminders #13
**Depends on:** #35 (RemindersLib extraction)

Moving a reminder between lists is a routine action. The remove + add workaround loses note, due date, and recurrence — a data loss footgun. Implementation belongs in RemindersLib alongside ChangeCommand after #35.

---

### 5. Multi-recipient text — text #10
**Depends on:** #39 (MessagesClient extracted into TextLib)

Sending to a group is a basic expectation. Implementation belongs in MessagesClient after #39 extracts it.

---

### 5. Monorepo migration — #34
**Depends on:** #35–39 (cleaner repos make migration less risky; each tool arrives well-structured)

Six repos with a shared library create friction on every cross-cutting change. Once the extractions are done, each tool repo is clean and well-structured — good time to bring them together. GetClearKit changes currently require push + `swift package update` in each tool repo. After migration: one Package.swift, one CI run, one place for everything.

Full plan in the issue. Key steps: git filter-repo for history, gh issue transfer for open issues, API recreation with backlinks for closed issues, single Package.swift, CI path filters, archive tool repos.

**Unblocks:** #33, reduced friction on all future cross-cutting work.

---

### 6. Command migration — #33
**Depends on:** #34 (monorepo eliminates the push + `swift package update` per tool)

Roll the `Command` enum + `runCLI` pattern to the four remaining tools. contacts-cli is the reference implementation (commit 37e9a75). Order: text → mail → calendar → reminders. In the monorepo, this is a single Package.swift change — no cross-repo coordination required.

**Unblocks:** cleaner dispatch layer for future work.

---

### 7. Gmail support — #14
**Depends on:** #38 (mail extraction)

The majority of the target audience is on Gmail. Shipping without it means mail doesn't work for most users on day one. This is a hard launch blocker.

OAuth2 flow, Google Cloud Console app registration, browser consent. `mail setup gmail` triggers OAuth; `mail setup fastmail <token>` stays as-is. README needs two setup paths after this ships.

---

### 8. GetClearKit shared utilities — #40
**Depends on:** #35–39 (extracted interfaces define what can be centralized)

Four patterns duplicated across all five tools: `what` command (identical in every main.swift), multi-match disambiguation, field-update parsing, unified error type. Centralizing these collapses repetition and makes the patterns testable.

---

### 9. Test coverage — #41, #42, #43, #44, #45
**Depends on:** #35–39 (logic must be in Lib targets before it can be tested)

| Issue | Tool | Priority cases |
|---|---|---|
| #41 | reminders | ChangeCommand field variants, recurrence conversion |
| #42 | calendar | EventDateTime edge cases (malformed input, boundary dates) |
| #43 | contacts | ChangeCommand variants, multi-match |
| #44 | mail | Config parsing, JMAP response handling, send edge cases |
| #45 | text | appleScriptLiteral injection safety |

---

### 10. Bundle Claude Code skills — #30
**Depends on:** nothing (independent)

Can be worked in parallel with any of the above. Skills are the Claude integration layer — without them, new users have no Claude-first experience out of the box. One skill file per tool, installed to `~/.claude/skills/` by both PKG and curl installer.

---

### 11. Install validation — Phase 2
**Depends on:** all code changes complete (do last)

Manual testing on a clean macOS account:
- PKG: Gatekeeper acceptance, postinstall browser open, permission prompts for each tool
- curl installer: all five binaries, PATH patch, next-steps output
- First-run flow: `reminders list`, `calendar today`, `contacts lists`, `text open`, `mail setup`
- calendar without config: acceptable fallback behavior

---

## Not blocking launch

These are good work but wait until real users are using the tools:

| Item | Issue | Notes |
|---|---|---|
| Emoji shortcode expansion | #17 | Polish; high delight but not correctness |
| Contextual subcommand help | #28 | Companion to --help guard (done) |
| mail draft command | mail #18 | Stage without sending |
| mail find + reply | mail #10, #11 | Completes the mail loop |
| JMAP session cache | mail #4 | Performance, not correctness |
| Google Calendar | calendar #12 | Evaluate post-v1 |

---

## Critical path summary

```
#35–39 extractions (per tool, one at a time)
  └── #35 reminders extraction
        └── reminders #13 move reminder to list
  └── #36 calendar extraction
        └── calendar #15 calendar change
  └── #39 text extraction
        └── text #10 multi-recipient text
  └── #38 mail extraction
        └── #14 Gmail ← hard user-facing blocker
  └── #34 monorepo ← after repos are clean
        └── #33 command migration ← easier in monorepo
  └── #40 shared utilities
  └── #41–45 test coverage

#30 bundle skills ← independent, work in parallel

Phase 2 install validation ← last, after all code
```

**Minimum to ship:** #35–39 → #34 → #33 → #14 → reminders #13 → calendar #15 → text #10 → #40 → #41–45 → #30 → Phase 2
