# Retrospective Spec Review

Evaluation of each spec for gaps, open questions, and areas to strengthen. These are not bugs — they're places where the specs could do more work: missing scenarios, thin edge cases, unresolved design questions, or claims that will go stale.

Use these as seeds for spec-improvement sessions or as prompts when the related feature gets revisited.

---

## 004 — GetClearKit

### What's strong
ANSI, fail(), flags, and the date/range parser requirements are well-covered. The "tombstone files" and "test targets vs lib targets" edge cases are particularly good documentation of non-obvious decisions.

### Gaps and questions

**User stories are developer-facing, not user-facing**
All three stories are from the perspective of "a developer adding a sixth tool." But GetClearKit has no sixth-tool users today — the real users are end users who benefit from the *consequences* of GetClearKit (color, errors, consistent dates). Reframe: write a user story about why a user notices that `reminders add "Test" friday` and `calendar list friday` land on the same day — consistency is the user-visible contract.

**`formatDate()` has no user story or success criterion**
It's in Key Entities, but no scenario drives it. How does it behave when `showTime` is false? Does locale affect the output? What format does it produce exactly? This matters because recap displays completion dates.

**What does nil from `parseDate()` look like to the user?**
The spec documents what parses, but not what happens when parsing fails. Does the tool show "Error: couldn't understand date 'asdf'"? Or does it fall through silently? The failure mode isn't in the FRs.

**Test count will go stale**
"235 tests as of 2026-03-19" will be wrong by next week. Either remove the count from the status line or replace it with a CI badge. Consider a different SC: "zero skipped or xfailed tests" rather than a specific count.

**`ANSI.enabled` and stderr**
The 003 spec notes that `fail()` checks stdout's isatty, not stderr's. That's a known trade-off. But it's not in this spec at all. Someone reading 004 alone will wonder: if NO_COLOR is set, does the "Error:" prefix still appear? (Yes, without color, but with the text.) Worth surfacing here even if it points to 003.

**What happens if EventKit permissions are denied at the GetClearKit layer?**
GetClearKit itself doesn't touch EventKit — it's framework-free. But the assumption that "tools fail with a clear error" when permissions are denied is actually owned by the tools, not GetClearKit. The spec should clarify GetClearKit's scope boundary here.

---

## 005 — Distribution

### What's strong
Stapler limitation, legacy PKCS12 format, and /usr/local/bin rationale are exactly the kind of "why not" documentation that prevents re-litigating decisions. The Design Notes are the best section in this spec.

### Gaps and questions

**`get-clear update` is mentioned but not spec'd**
The curl installer is described as "the auto-update mechanism when `get-clear update` is run" — but `get-clear update` has its own spec (002). The relationship between install.sh and the update command deserves a cross-reference, and the install.sh behavior when called via `update` (vs. fresh install) should be clarified. Does `update` just re-invoke install.sh? Or is there a separate mechanism?

**What happens when the README doesn't exist?**
The PKG postinstall script "opens README in browser after install" — but the README (Phase 1) is the main blocker to public launch. What URL does it open? Does it 404? This is an open design issue that should be captured here as a known gap.

**Failure scenarios are absent**
No coverage of: what if a binary download fails mid-install? What if notarization is rejected (invalid binary, quarantine issue)? What if the cert expires mid-CI? The installer should fail clearly in all these cases, not silently leave a partial install.

**Which Keychain credentials does the uninstaller remove?**
The uninstaller "removes config/Keychain credentials" when the user confirms. But which ones? mail-cli's JMAP token? The signing certs? Only the tool credentials, not the signing infrastructure? FR-007 is vague. A specific list (e.g., "Keychain entry: service `mail-cli`, account `kscott@imap.cc`") would make this testable.

**Minimum macOS version is missing**
EventKit, osascript via Messages.app, JMAP — what's the floor? If someone runs the PKG on an old macOS, what happens? This belongs in Assumptions and should be a FR.

**Phase 2 (clean-machine install validation) is noted as incomplete in going-live.md**
The spec doesn't acknowledge this. Add a note: "Phase 2 clean-machine validation has not been completed. PKG has only been installed on machines that already had tool dependencies configured."

---

## 006 — Calendar Setup

### What's strong
The "interactive wizards are the exception" design note captures a key suite principle. Cross-linking to `get-clear setup` as the pattern consumer is good.

### Gaps and questions

**How does multi-calendar selection work?**
FR-003 says "select by number or name" — but setup presumably allows selecting multiple calendars. The spec doesn't describe the multi-select interaction at all. Is it: enter one number at a time, press enter after each, then empty line to finish? Enter comma-separated numbers? This is the core UX and it's absent from the spec.

**What subset does setup always configure?**
FR-004 says "the appropriate subset (e.g., `[work]` section)" — but "appropriate" is doing a lot of work. Does setup always write `[work]`? Can the user configure multiple subsets? If someone wants both `[work]` and `[personal]`, do they run setup twice? The TOML schema and multi-subset workflow is unspecified.

**What does the user actually see and type?**
No sample interaction is shown. The spec describes the behavior but not the UX text. What's the prompt? "Enter calendar numbers (comma-separated, or press Return to finish):" or "Enter number to add/remove (blank to finish):"? For a feature whose entire value is the interaction, this omission is significant.

**Permissions-denied scenario**
Mentioned in Assumptions but not in Edge Cases or FRs. What does the user see if EventKit calendar access hasn't been granted? "Error: Calendar access denied. Grant access in System Settings > Privacy > Calendars." This should be an explicit FR.

**No test for an empty calendar list**
A user with no calendars (or no access) gets an empty numbered list. What does setup do? Error? Proceed with no selection? Not addressed.

---

## 007 — Shell Completions

### What's strong
The `fpath` ordering constraint and ANSI stripping are well-documented. "Command-level completions are the floor" is a good design note.

### Gaps and questions

**FR-004 is incomplete — title completions exist but aren't required**
The Edge Cases section mentions "completion for `show`/`change`/`done`/`remove` fetch live reminder titles" — but this is in Edge Cases, not FRs. Either this is implemented (in which case, add an FR) or it isn't (in which case, remove it from Edge Cases). There's a gap between what's documented and what's required.

**The permission dialog problem**
When completions call `reminders lists` and Reminders hasn't been granted permission yet, macOS will show a permission dialog in the middle of a Tab completion. This is a jarring UX. Is there a check before the binary call? Or is the failure mode just "no completions" on first run? This is unaddressed.

**Calendar subset completion mechanics differ from list/group**
Reminder list names come from a live binary call. Calendar subset names come from config.toml (not a live binary call). The mechanics are different, but the spec treats them identically. How does the calendar completion actually get subset names? From `calendar calendars`? From parsing config.toml directly? From `calendar --subsets` (which may not exist)?

**`get-clear` completions?**
The get-clear binary has commands (`what`, `recap`, `setup`, `update`). Are there completions for it? The spec covers only the five tools, but `get-clear` is a sixth CLI. This should be noted as in scope or explicitly excluded.

**Completion staleness**
If a new command is added to a tool (e.g., `reminders batch`), the completions file must be manually updated. The spec notes this as a maintenance step, but there's no mechanism to detect drift. Is there a test or CI check for completions being up to date?

**Performance bound**
"~100ms latency" is an assumption. A user with 5,000 reminders across 10 lists might see a 500ms pause. No guidance on what to do if completions become slow. Should there be a timeout after which completions fall back to nothing?

---

## 008 — MCP Server

### What's strong
"Tool descriptions as agent contracts" is the most important design note in all eight specs — it explains why the MCP approach works better than documentation alone. The "shells out, does not reimplement" principle is correctly identified as the load-bearing decision.

### Gaps and questions

**`mail_show` doesn't exist**
User Story 3 says "Claude drafts the email and calls `mail_show` before `mail_send`." There is no `mail_show` tool. The pre-send confirmation is done by Claude presenting the parameters from its own context, not by calling a separate tool. This is factually wrong and should be corrected — Claude displays the To, Subject, Body from the `mail_send` parameters before calling it.

**No user story for contacts tools**
Reminders (stories 1, 2), mail/SMS (story 3) — contacts has 4 tools but no coverage. A scenario like "Claude looks up Ann's email before drafting a message" would be valuable and represents a real usage pattern.

**How does the MCP server update when a new version ships?**
After `get-clear update` runs, the binaries are updated. The MCP server itself is registered pointing to a path — does it need to be re-registered? Or does it pick up new binaries automatically since it resolves them at runtime? This is worth clarifying in the spec or a Design Note.

**22 tools will drift**
The tool count is a snapshot. As new operations are added (`reminders_open`? `calendar_show`?), the count changes. Better to say "all operations across all five tools" and list the specific tools in Key Entities rather than leading with a count.

**SC-003 is untestable as written**
"Claude calls `reminders_show` before `reminders_done` — confirmed by session observation." This is not a repeatable test. How do you verify the contract holds? The only real answer is "Claude is reliable enough to follow tool description guidance" — which is an empirical assumption, not a SC. Consider replacing with: "The tool description for `reminders_done` explicitly requires a prior `reminders_show` call — verify the description text contains this requirement."

**MCP server crash behavior**
What does Claude Code show the user if the MCP server process crashes or fails to start? Is there a watchdog? Does Claude gracefully degrade to direct Bash tool use? Not addressed.

**Authentication / sandboxing**
Not a security gap for a local personal tool, but worth noting: the MCP server runs as the user, has access to all five tool CLIs, and can execute any command they support. If another MCP server or process on the machine could send requests to it, it would be a local privilege escalation. This is an acceptable trade-off but should be acknowledged.

---

## 009 — Multi-Match

### What's strong
The design note about "protective, not annoying" and the contrast between `find` (browse) and `done`/`remove` (act) is exactly the right framing. Concise and correct.

### Gaps and questions

**Thin on scenarios — only one user story**
The spec has one user story and it's the primary case. Missing scenarios:
- Claude uses `reminders_find` to get a title, then calls `reminders_done` — does it still need to handle disambiguation, or did `find` + `show` resolve it already?
- The user makes a typo in the disambiguation command — what does the error look like?

**Output format is unspecified**
The spec says "numbered candidate list" in the Input section but FR-002 just says "list all candidates with their list names." Is it numbered? Does it look like:
```
Multiple reminders match "Pay rent":
  1. Pay rent  [Personal]
  2. Pay rent  [Household Finances]
Narrow with: reminders done "Pay rent" <list>
```
Or something else? The exact format matters for Claude to parse the output correctly. This should be in the spec.

**Calendar disambiguation uses a different key**
Calendar's remove command disambiguates by `[date]`, not `[list]`. Reminders uses `[list]`. This asymmetry is not discussed — the spec says the pattern is "suite-wide" but the disambiguating key differs by tool. That's worth calling out explicitly.

**Contacts disambiguation**
If the user has two contacts named "Ann Smith", does `contacts show "Ann Smith"` trigger disambiguation? Not addressed. Contacts has a different data model (no "lists") so the disambiguation key would be something else (company? email?).

**Same title in the same list**
The Assumptions section says "the behavior is undefined" if the same title exists twice in one list. EventKit shouldn't allow this, but what if the database is corrupt or the user created it programmatically? Should the spec say "the first match wins and the user is not warned"?

---

## 010 — Date Parsing

### What's strong
The "EventKit loop" story (recap consumes its own formatDate output) is clear and the root cause is well documented. The "each format addition gets tests before ship" discipline note is worth keeping.

### Gaps and questions

**Failure modes are absent**
The spec documents what parses. It doesn't document what doesn't. Inputs like `"next month"`, `"in 3 days"`, `"Q2"`, `"Monday next week"`, `"asap"` all return nil — but the spec doesn't say so. A table of "supported" vs "not supported" inputs would help Claude avoid generating unsupported formats.

**"friday" when today is Friday**
`DateParser` uses `Calendar.nextDate(after: now, matching:)` for weekday matching. This means if today is Friday, `"friday"` returns *next* Friday (7 days from now), not today. Is this correct? For a reminder, "friday" when it's Friday might mean today. This is a real edge case with a non-obvious answer. The spec should document the decision and why.

**"next friday" vs bare "friday"**
The spec says "next friday" and "this monday" strip the prefix and behave identically to the bare weekday. But "next friday" conventionally means "the Friday of next week" (not this week), while "friday" means "the coming Friday." The spec says they're the same — if so, that's worth an explicit design note, because it's counterintuitive.

**Invalid time inputs**
What does the parser return for `"13pm"`, `"25:00"`, `"14:75"`? nil? Or does it clamp? Not documented.

**The parser doesn't handle relative offsets**
"In 3 days," "2 weeks from now," "next quarter" are not supported. This is fine — but Claude sometimes generates these. The spec should note what Claude should be told to avoid.

**`hasDate: false` behavior**
When `hasDate` is false (time-only input like `"3pm"`), the date defaults to today. But what time on today? The parser sets `components.hour = 9` as a fallback — so if you parse `"3pm"`, does it return today at 3pm? Yes. But the spec doesn't explicitly state "time-only input defaults the date to today." It says `hasDate` is false but leaves "callers should treat this as a date-only value" which is the opposite direction.

---

## 011 — List Moving

### What's strong
The "change vs remove+add" design note captures exactly why this feature exists and why it was implemented as a keyword rather than a new command. Short and clean.

### Gaps and questions

**Keyword collision: a reminder titled "list"**
If the user has a reminder with the title "list", `reminders change "list" list Ibotta` would parse as: find reminder "list", change its list to "Ibotta." That's probably correct — but what about `reminders change "list" Personal`? Does the parser read "Personal" as a source-list or as the value of the `list` keyword? This is a genuine ambiguity worth testing and documenting.

**Multi-word list names via MCP vs shell**
The spec notes that `list "My Projects"` requires shell quoting. Via MCP, `target_list="My Projects"` works cleanly. This asymmetry is mentioned but not resolved — should the shell version support multi-word list names without quotes? How? This is an open design question.

**Only one user story**
The spec has one story. Missing: a Claude-driven story using MCP (the primary path this feature is used). "The user says 'move this reminder to my work list.' Claude calls `reminders_change` with `target_list='Ibotta'`." The MCP path is at least as important as the shell path.

**Success criteria count drift**
"200 tests" was the count when this shipped. It's now higher. Same issue as 004 — use a relative criterion ("20 new tests added for list moving, all passing") or drop the absolute count.

**`list` collision with `reminders list`**
Less a spec gap, more a design question: `list` is both a command (`reminders list`) and a keyword in `change`. In natural language, "change my reminder's list" is fine. But could Claude confuse the two? Worth noting as a Claude-interaction edge case in the MCP context.

**No coverage of what happens to the completion after move**
If `reminders list Ibotta` is called right after moving a reminder into Ibotta, does the moved reminder appear? This is an EventKit consistency question — does EventKit return the updated state immediately after `save`? Probably yes, but worth noting.

---

## Cross-Cutting Observations

**All specs: success criteria are point-in-time assertions**
Test counts, "all five tools are clean" — these go stale. The more durable pattern is behavior-based: "a tool without ANSI helpers still compiles and produces correct output" rather than "no tool repo contains inline ANSI helpers."

**All specs: no coverage of the "what does Claude see" experience**
These tools are Claude-first, but the specs are mostly written from the human CLI user's perspective. For most features, the more important path is Claude calling the MCP tool and parsing the output. A "Claude experience" section or user story in each spec would strengthen the Claude-first framing.

**All specs: permissions and first-run are underspecified**
On a clean machine, six separate macOS permission dialogs will fire (Reminders, Contacts, Calendar × 3 for each). The first `reminders add` will trigger a permission prompt mid-command. This is a real first-run experience issue that no spec addresses.

**004 and 005 overlap on "what is GetClearKit"**
004 documents the package; 005 documents the distribution. But neither spec explains how GetClearKit is distributed — it's embedded in the tools via Swift package resolution at build time, not as a separate binary. A new team member reading these specs might think GetClearKit is a separate download. Worth clarifying in one of the two specs.

**009, 011 are thin**
Both are correct and complete on the implemented feature, but they read more like release notes than specs. A good spec should be useful for understanding a feature even if you never read the source code. Both could use an expanded "what does this look like" section with actual output examples.
