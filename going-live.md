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

---

## Blockers — ordered by dependency

Nothing ships until all of these are done. Order matters.

### 1. ✅ Extract business logic from main.swift — #35, #36, #37, #38, #39
All five extractions complete. Each tool's main.swift is now ≤60 lines — dispatch and lifecycle only.

| Issue | Tool | Result |
|---|---|---|
| #35 ✅ | reminders | RecurrenceConversion, ReminderFormatter, ChangeCommand — 188 tests |
| #36 ✅ | calendar | EventDateTime, EventFormatter, CalendarResolver — 128 tests |
| #37 ✅ | contacts | ChangeCommand, ContactStore, ContactFormatter |
| #38 ✅ | mail | MailErrors, MailConfiguration, JMAPClient, MailFormatter, SetupCommand, SendCommand — 72 tests |
| #39 ✅ | text | MessagesClient (appleScriptLiteral, buildScript), TextErrors — 55 tests |

---

### 2. Monorepo migration — #34
**Depends on:** #35–39 ✅

Six repos with a shared library create friction on every cross-cutting change. Each tool repo is now clean and well-structured — right time to consolidate. GetClearKit changes currently require push + `swift package update` in each tool repo. After migration: one Package.swift, one CI run, one place for everything.

Full plan in the issue. Key steps: git filter-repo for history, gh issue transfer for open issues, API recreation with backlinks for closed issues, single Package.swift, CI path filters, archive tool repos. release.yml and bump-version both require rewrites.

**Bundles:** #49 (versionString into GetClearKit) — touching all repos in migration makes this a free addition.

**Unblocks:** #33 and all future cross-cutting work.

---

### 3. Command migration — #33
**Depends on:** #34

Roll the `Command` enum + `runCLI` pattern to the four remaining tools. contacts-cli is the reference implementation (commit 37e9a75). Order: text → mail → calendar → reminders. In the monorepo, this is a single commit — no cross-repo coordination required.

---

### 4. Gmail support — #14
**Depends on:** #38 ✅

The majority of the target audience is on Gmail. Shipping without it means mail doesn't work for most users on day one. This is a hard launch blocker.

OAuth2 flow, Google Cloud Console app registration, browser consent. `mail setup gmail` triggers OAuth; `mail setup fastmail <token>` stays as-is. README needs two setup paths after this ships.

---

### 5. Feature additions — calendar #15, reminders #13, text #10
**Depends on:** #34 (do these in the monorepo — each touches both Lib and CLI targets)

| Issue | Feature | Notes |
|---|---|---|
| calendar #15 | `calendar change` | Implementation in CalendarLib alongside EventFormatter and CalendarResolver |
| reminders #13 | Move reminder to list | Remove + add workaround loses note, due date, recurrence — data loss footgun |
| text #10 | Multi-recipient text | Implementation in MessagesClient |

---

### 6. GetClearKit shared utilities — #40
**Depends on:** #34 (monorepo makes centralization a single commit)

Four patterns duplicated across all five tools: `what` command (identical in every tool), multi-match disambiguation, field-update parsing, unified error type. Centralizing these collapses repetition and makes the patterns testable.

---

### 7. Test coverage — #41, #42, #43, #44, #45
**Depends on:** #35–39 ✅ (logic must be in Lib targets before it can be tested)

| Issue | Tool | Priority cases | Status |
|---|---|---|---|
| #41 | reminders | ChangeCommand field variants, recurrence conversion | Open |
| #42 | calendar | EventDateTime edge cases (malformed input, boundary dates) | Open |
| #43 | contacts | ChangeCommand variants, multi-match | Open |
| #44 | mail | Config parsing, JMAP response handling, send edge cases | Open |
| #45 | text | appleScriptLiteral injection safety | Substantially done in #39; Unicode + long string cases remain |

---

### 8. Bundle Claude Code skills — #30
**Depends on:** nothing (independent)

Can be worked in parallel with any of the above. Skills are the Claude integration layer — without them, new users have no Claude-first experience out of the box. One skill file per tool, installed to `~/.claude/skills/` by both PKG and curl installer.

---

### 9. Install validation — Phase 2
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

#34 monorepo          ← next; bundles #49 (versionString)
  └── #33 command migration
  └── #14 Gmail       ← hard user-facing blocker
  └── calendar #15    ← calendar change (in monorepo)
  └── reminders #13   ← move to list (in monorepo)
  └── text #10        ← multi-recipient (in monorepo)
  └── #40 shared utilities
  └── #41–45 test coverage

#30 bundle skills     ← independent, work in parallel

Phase 2 install validation ← last, after all code
```

**Minimum to ship:** #34 → #33 → #14 → calendar #15 → reminders #13 → text #10 → #40 → #41–45 → #30 → Phase 2
