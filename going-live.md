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
| #35 — reminders-cli main.swift extraction (43 lines, 188 tests) | 2026-04-11 |
| #36 — calendar-cli main.swift extraction (60 lines, 128 tests) | 2026-04-11 |
| #37 — contacts-cli main.swift extraction (455 lines → ChangeCommand, ContactStore, ContactFormatter) | 2026-04-13 |
| #38 — mail-cli main.swift extraction (670 lines → MailErrors, MailConfiguration, JMAPClient, MailFormatter, SetupCommand, SendCommand; 72 tests) | 2026-04-13 |
| #39 — text-cli main.swift extraction (181 lines → MessagesClient, TextErrors; 55 tests, appleScriptLiteral injection coverage) | 2026-04-13 |
| #34 — Monorepo migration: all six repos consolidated, standalone repos archived | 2026-04-16 |
| #33 — Command enum + runCLI across all five tools | 2026-04-16 |
| #139 — Async/await migration; UpdateChecker moved into runCLI | 2026-04-22 |

---

## Blockers — ordered by dependency

Nothing ships until all of these are done. Order matters.

### 1. ✅ Extract business logic from main.swift — #35, #36, #37, #38, #39
All five extractions complete. Each tool's main.swift is now ≤60 lines — dispatch and lifecycle only.

| Issue | Tool | Result |
|---|---|---|
| #35 ✅ | reminders | RecurrenceConversion, ReminderFormatter, ChangeCommand |
| #36 ✅ | calendar | EventDateTime, EventFormatter, CalendarResolver |
| #37 ✅ | contacts | ChangeCommand, ContactStore, ContactFormatter |
| #38 ✅ | mail | MailErrors, MailConfiguration, JMAPClient, MailFormatter, SetupCommand, SendCommand |
| #39 ✅ | text | MessagesClient (appleScriptLiteral, buildScript), TextErrors |

---

### 2. ✅ Monorepo migration — #34
All six repos consolidated into `~/dev/get-clear/`. Standalone repos archived. One Package.swift, one CI run, history preserved via git filter-repo. Closed 2026-04-16.

---

### 3. ✅ Command migration — #33
`Command` enum + `runCLI` rolled out to all five tools. Closed 2026-04-16.

---

### 4. ✅ Async/await migration — #139
All five tools migrated from DispatchSemaphore to async/await. UpdateChecker moved into `runCLI`. Closed 2026-04-22.

---

### 5. reminders-cli second-pass refactors — #144

Output formatting, arg parsing duplication, `describeEKRule`, grouping logic, remove-completed decision. These are structural problems visible in the current code — address them before introducing the protocol layer so the abstraction is built on clean foundations.

---

### 6. Protocol abstractions — #147, #140, #141, #142, #143
**Depends on:** #144 (reminders pattern establishes the template)

Introduce store protocols and Apple-backed implementations for each tool. #147 (reminders) first — it's the reference pattern. Then #140–143 in any order.

| Issue | Tool | What ships |
|---|---|---|
| #147 | reminders | `ReminderStore` protocol, `AppleReminderStore`, `ListItem`, `StoreFactory` — prerequisite for Google Tasks (#146) |
| #140 | calendar | `CalendarStore` protocol, `CalendarEventKit` target, `EventItem` conversion layer |
| #141 | contacts | `ContactStore` protocol, `ContactsApple` target, `ContactItem` conversion layer |
| #142 | mail | `MailClient` protocol, `MailJMAP` target, uniform async handlers |
| #143 | text | `MessageSender` protocol, `TextMessages` target, `MessageContact` boundary |

---

### 7. Gmail support — #61
**Depends on:** #142 ✅ (MailClient protocol makes adding a second backend straightforward)

The majority of the target audience is on Gmail. Shipping without it means mail doesn't work for most users on day one. This is a hard launch blocker.

OAuth2 flow, Google Cloud Console app registration, browser consent. `mail setup gmail` triggers OAuth; `mail setup fastmail <token>` stays as-is. README needs two setup paths after this ships.

---

### 8. Feature additions — #53, #80, #68
**Depends on:** monorepo ✅ (each touches both Lib and CLI targets)

| Issue | Feature | Notes |
|---|---|---|
| #53 | `calendar change` | Implementation in CalendarLib alongside EventFormatter and CalendarResolver |
| #80 | Move reminder to list | Remove + add workaround loses note, due date, recurrence — data loss footgun |
| #68 | Multi-recipient text | Implementation in MessagesClient |

---

### 9. GetClearKit shared utilities — #40
**Depends on:** monorepo ✅

Four patterns duplicated across all five tools: `what` command (identical in every tool), multi-match disambiguation, field-update parsing, unified error type. Centralizing these collapses repetition and makes the patterns testable.

---

### 10. Test coverage — #41, #42, #43, #44, #45
**Depends on:** #35–39 ✅ (logic must be in Lib targets before it can be tested)

| Issue | Tool | Priority cases | Status |
|---|---|---|---|
| #41 | reminders | ChangeCommand field variants, recurrence conversion | Open |
| #42 | calendar | EventDateTime edge cases (malformed input, boundary dates) | Open |
| #43 | contacts | ChangeCommand variants, multi-match | Open |
| #44 | mail | Config parsing, JMAP response handling, send edge cases | Open |
| #45 | text | appleScriptLiteral injection safety | Substantially done in #39; Unicode + long string cases remain |

---

### 11. Bundle Claude Code skills — #30
**Depends on:** nothing (independent)

Can be worked in parallel with any of the above. Skills are the Claude integration layer — without them, new users have no Claude-first experience out of the box. One skill file per tool, installed to `~/.claude/skills/` by both PKG and curl installer.

---

### 12. Install validation — Phase 2
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
✅ #35–39  All five extractions done
✅ #34     Monorepo migration
✅ #33     Command enum + runCLI across all tools
✅ #139    Async/await migration

#144  reminders second-pass refactors      ← start here
  └── #147  ReminderStore protocol + AppleReminderStore
  └── #140  CalendarStore protocol + CalendarEventKit
  └── #141  ContactStore protocol + ContactsApple
  └── #142  MailClient protocol + MailJMAP
        └── #61  Gmail              ← hard user-facing blocker
  └── #143  MessageSender protocol + TextMessages

#53, #80, #68  feature additions (calendar change, move to list, multi-recipient text)
#40   GetClearKit shared utilities
#41–45 test coverage per tool

#30   bundle skills     ← independent, work in parallel
#135  smoke tests       ← independent

Phase 2 install validation ← last, after all code
```

**Minimum to ship:** #144 → #147, #140–143 → #61 (Gmail) → #53, #80, #68 → #40 → #41–45 → #30 → #135 → Phase 2
