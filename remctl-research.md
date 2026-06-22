# remctl Research Notes

Notes from a deep read of Viticci's [remctl](https://github.com/viticci/remctl), cloned to `~/dev/remctl/`. Session: 2026-06-22.

---

## What remctl is

A Python CLI that reads Apple Reminders directly from CoreData SQLite and writes through EventKit (via a Swift bridge) and Apple's private ReminderKit framework (via an ObjC helper). It's the most complete Reminders CLI that exists — it surfaces everything the Reminders.app UI can do, including features EventKit doesn't expose.

Architecture:

```
remctl (Python)
  reads:   ~/Library/Group Containers/group.com.apple.reminders/.../Data-*.sqlite
  writes:  remctl-bridge (Swift/EventKit)
  private: remctl-private (ObjC/ReminderKit private framework)
```

Requires Xcode Command Line Tools (`swiftc` for the bridge, `clang` for the private helper). The main Python CLI and reads work without them, but writes fall back to AppleScript and `--private` is unavailable. Full Xcode is not required — CLT only.

---

## Similarities in tone and concept

Both tools make the same philosophical bet: natural English verbs (`add`, `list`, `find`, `done`, `remove`/`delete`, `show`) rather than CRUD flags. Both are macOS-native, daemonless, support natural language dates, ANSI-colored output, priority, notes, and URL. The command vocabulary overlap is striking — Viticci thought through the same problem independently.

The biggest tonal difference: remctl is built for automation and agent pipelines. Get Clear is built for humans at a terminal (and Claude in parallel). That's intentional — "claude parallel," not "claude first."

---

## What remctl does that reminders-cli doesn't

### Tier 1: Pure EventKit — doable now, no private APIs

| Feature | Status |
|---|---|
| `today` — all incomplete due today across lists | Missing (tracked in #155) |
| `overdue` — past-due across lists | Missing |
| `upcoming N` — next N days | Missing |
| `flagged` — all flagged reminders | Missing (requires SQLite or private API for real flag state) |
| `--format json` output | Missing (see decision below) |
| `undone` — un-complete a reminder | Missing |
| `link` — get deep link URL for a reminder | Missing |
| `export` JSON/CSV | Missing |

### Tier 2: Requires reading SQLite directly

Direct SQLite reads give remctl access to fields EventKit doesn't expose:

- **Tags** — real Reminders tags (not inline `#hashtags` in the title)
- **Subtasks** — the full child reminder tree
- **Sections** — which section a reminder belongs to within its list
- **Urgent state** — macOS 26 ⏰ feature
- **Early Reminders** — the "15 minutes before" private delta alert
- **Attachments** — image and rich link metadata
- **List badge/emblem** — private symbol or emoji on a list

Requires Full Disk Access.

### Tier 3: Private ObjC helper (`remctl-private.m`)

The pattern: a tiny ObjC binary compiled against the private `ReminderKit.framework`. Accepts JSON on stdin, dispatches to one of ~27 named actions, writes through `REMSaveRequest`. Never touches SQLite directly.

Key private API classes:
- Tags: `REMReminderHashtagContextChangeItem.addHashtagWithType:name:`
- Subtasks: `REMSaveRequest.addReminderWithTitle:toReminderSubtaskContextChangeItem:`
- Sections: `REMMembership` + `REMListSectionContextChangeItem`
- Early Reminders: `REMDueDateDeltaInterval` via `dueDateDeltaAlertContext`
- Urgent: `REMReminderUrgentAlarmContextChangeItem`
- Location alarms: `REMAlarmLocationTrigger`
- List appearance: `REMListChangeItem.setColor:`, `appearanceContext.setBadgeEmblem:`
- Pinning: `REMListChangeItem.setIsPinned:`, `REMSmartListChangeItem.setIsPinned:`
- List groups: `REMSaveRequest.addGroupWithName:toAccountGroupContextChangeItem:`
- Smart lists: `REMSaveRequest.addCustomSmartListWithName:toAccountChangeItem:`
- Templates: `REMSaveRequest.addTemplateWithName:configuration:toAccountChangeItem:`

---

## What reminders-cli does better

1. **Architecture** — pure value type boundary (`ReminderItem` at the lib layer, EventKit types converted at the edge) is cleaner and more testable than remctl's Python + multi-process split.
2. **Verb vocabulary** — `change` (not `edit`), `remove` (not `delete`), `rename` as a distinct command. More natural for conversational use.
3. **No required Full Disk Access** — works out of the box; EventKit only.
4. **Sort options on `list`** — `list [name] [by due|priority|title|created]`.
5. **`what` command** — doesn't exist in remctl.

---

## Three improvements that would matter most

**1. `today`, `overdue`, `upcoming` views (pure EventKit)**
Most-used cross-list read patterns. Already tracked in #155. Fetch all incomplete items, filter by due date. Zero private API needed.

**2. `--format json` output**
Get Clear is "claude parallel" — Claude and the tool are peers. For the tool to be useful in a pipeline, it needs machine-readable output. Decision: expose `--format json` only through the skill, not in the human-facing help text or UI. Keeps the human experience clean; gives Claude what it needs. Follows the same principle as remctl, which also separates human UX from agent UX.

**3. ObjC private helper for tags and subtasks**
Tags are the #1 feature Reminders users notice missing from CLI tools. Subtasks are #2. The `remctl-private.m` file has the exact method signatures. Start with just those two actions, wire in a `--private` guardrail (or an environment variable — see below).

---

## The `--private` flag design

remctl's most admirable architectural decision. Every command that touches a private API must include `--private` explicitly at the call site. If you omit it, the command fails before touching anything.

**Why this matters:** without the guardrail, a command that silently drops private metadata looks successful. You add a tag, get a confirmation, the tag never syncs. The `--private` requirement makes that failure mode impossible.

**Stability seam:** if Apple breaks the private helper in a future macOS update, only commands that explicitly opted in break. Everything else keeps working.

**The one exception:** moving a parent reminder with subtasks uses ReminderKit internally without `--private`, because EventKit rejects the operation entirely and there's no other path. He documents it explicitly as the exception that proves the rule.

### Environment variable alternative

For the skill use case, requiring `--private` on every invocation is friction without benefit — the choice was already made when the skill was written. An environment variable (e.g., `REMINDERS_PRIVATE=1`) set inside the skill's bash invocations would put the tool in private mode for Claude without affecting interactive shell sessions.

Precedent: remctl uses `REMCTL_BRIDGE_PATH`, `REMCTL_PRIVATE_PATH` etc. for helper overrides. An env var for mode is the same pattern.

**Important:** set it only within the skill's invocations, not exported to the shell environment. Don't let it leak into interactive sessions where the explicit guardrail still has value.

---

## SKILL.md patterns worth adopting

remctl ships a `SKILL.md` alongside the tool. Key structural patterns:

**Agent routing table** — maps user intent → command → whether a special flag is needed → what to verify with. Pre-answers the routing question before the model has to reason about it. Much stronger than embedding help text.

**Guardrails as explicit "do not" rules** — calls out things that look safe but aren't (wrong ID type passed to edit, features that aren't wired up). For Get Clear, this means argument order and positional gotchas.

**Verification step** — tells the agent what to run after a write to confirm it worked. For reminders: run `find` after `add`, run `show` after `change`/`done`/`remove`.

**Common commands block** — copy-paste examples covering the 80% cases. Agent-specific (normalized date formats, `--format json` on everything).

**Separation of human UX and agent UX** — `--format json` in the skill, not in help text or README. Same principle applies to Get Clear.

One thing our skills do that remctl's doesn't: the `` !`date` `` injection for current time. Worth keeping — lightweight way to anchor date parsing without the model having to reason about it.

Relevant issue: #30.

---

## EventKit gotchas documented in the bridge source

Things discovered from reading `remctl-bridge.swift` that aren't in Apple's docs:

**CloudKit due date bug (observed 2026-04-17):** Setting `dueDateComponents` with `.timeZone` included in the component set produces a CKRecord push that EventKit reports as successful but CloudKit silently ignores the dueDate field. The correct approach: set `dueDateComponents` *without* `.timeZone` in the component set, then set `reminder.timeZone = TimeZone.current` separately. This mirrors what Reminders.app itself does and produces a changedKeys set CloudKit accepts.

**Flagged state has no public API:** EventKit has no `isFlagged` property. remctl uses `priority = 1` as a proxy — it shows the flag indicator in Reminders.app. This is why `--private` is needed for real flag state: the proxy works visually but isn't the same field Reminders stores internally, and it conflicts with actual priority.

**`EKReminder.url` is not the Reminders URL field:** The public `url` property on `EKReminder` does not map to `ZICSURL`, which is what Reminders.app displays as a rich link. That's a private ReminderKit property. The EventKit fallback is to append the URL to notes, where it appears as a tappable link. Real rich link attachments require the private helper.

---

## Testing approach

remctl has two live test scripts in `scripts/` that are worth modeling:

- `live_edit_matrix.py` — creates disposable Reminders data, runs a matrix of edit/reschedule/alarm scenarios through the CLI, verifies JSON output, cleans up. Used to catch regressions in due date, alarm, and list-move behavior.
- `live_private_matrix.py` — same pattern but for all `--private` write paths: tags, sections, subtasks, smart lists, templates, etc.

He ran both against macOS 27 Golden Gate beta (build 26A5353q) and everything passed — the private APIs survived the OS update. 200 unit tests alongside the live matrices.

The key insight: live tests against real Reminders data catch things unit tests can't, because the failure mode is often "command succeeds but CloudKit silently discards the write." JSON output verification after the fact is the only reliable check.

---

## TCC scoping for agent contexts

From `docs/installation.md`: Full Disk Access is scoped to the exact process context. Terminal can pass `remctl doctor` while an agent runner (Codex, Claude Code, another host app) fails — same Mac, same install, different TCC grant.

The correct fix is running `doctor --for-agent` from the agent's execution context, then granting FDA to the target it prints. He also notes that when a terminal embeds another engine (e.g., Ghostty inside another app), `TERM_PROGRAM` can be misleading — trust the `host_app` path from `doctor --for-agent --json` instead.

This is directly relevant if Get Clear tools are ever used by Claude in non-Terminal contexts (e.g., an IDE extension or a cloud agent). The grant that works in Terminal doesn't carry over.

---

## Shared principles

remctl and Get Clear converge on the same instincts independently:

- **Write discipline** — never touch SQLite directly even when reading from it constantly. Every mutation goes through Apple's stack. The private helper is a separate binary with a bounded JSON interface, not arbitrary code. Same instinct as the pure value type boundary.
- **Explicit over implicit** — `--private` forces the user to be intentional about crossing into unsupported territory. Could have made tags just work transparently; chose not to.
- **Principled refusals** — no SQLite writes, no PDF attachments, no multi-list smart filters, no template link creation. Each refusal documented with the reason it was rejected during testing. "Don't design for hypothetical future requirements."
- **The happy path stays trustworthy** — power-user features are honest about what they are.
