# Mail Send UX — Human Interaction Design

Discussion captured 2026-05-10. Not a spec — a thinking document. Decisions pending.

---

## The foundational question: what is `send` allowed to do?

Everything else in this document depends on answering this first.

**Option A — `send` is pure execution.**
`send` only fires when every recipient is fully resolved and unambiguous. Any ambiguity or error stops the command before it does any work. The human is told exactly what went wrong and what to clarify. Re-runs with more specific input.

Consequence: the human uses `contacts find` (or retries with a precise address) before `send` can succeed in any ambiguous case. `send` itself is simple and honest — it either sends or it doesn't.

**Option B — `send` owns the full pipeline.**
`send` searches, resolves, disambiguates (via picker if needed), confirms, and sends. The human types one command and the tool handles everything, including asking questions mid-flow.

Consequence: `send` is complex. Dirty scenarios (partial failure, mixed resolution) produce awkward mid-command interactions. The picker is buried inside what looks like an execution command.

**Option C — two commands.**
`mail compose ...` resolves recipients and previews the full message. `mail send` executes a composed message. State is carried between commands somehow.

Consequence: stateful, which conflicts with the current tool design. Probably not viable.

---

**The tension:**

Option A is cleaner and more honest — `send` does one thing. But it puts more burden on the human for the common case (any group send, any name with multiple matches). The human has to know to run `contacts find` first, and then re-express the recipient as something unambiguous.

Option B is friendlier for the happy path but degrades badly when things are messy. Partial commitment (picker fires, then an error elsewhere kills the operation) is the worst outcome.

A variant of Option A worth considering: `send` resolves everything first, and if the result is fully unambiguous, proceeds to confirmation and send. If anything is ambiguous or missing, it reports the complete state — all successes and all problems together — and stops. No partial work. The human fixes the problems and re-runs. The confirmation step only appears when `send` has a clean, complete message to show.

This variant gives the human the friendly path when everything resolves cleanly, and the clean failure path when it doesn't. No mid-send picker. No partial commitment.

---

**Decision needed:** Which option? This determines the architecture of `buildRecipients`, whether `InteractivePicker` belongs in the send pipeline at all, and how all the dirty scenarios are handled.

---

## First principle: both actors are first class

Both a human user and Claude are first-class actors for every command. The design cannot optimize for one at the expense of the other, and neither is a workaround for the other.

This has a direct implication for `mail send`: the tool must work cleanly for a human typing natural language names AND for Claude passing pre-resolved RFC 5322 addresses. These are not two modes — they are two valid inputs to the same command.

---

## Two valid input forms

**Name query** — human or Claude passes a name or group name:
```
mail send council cc finance-committee subject "Q3 Update" body "..." attach report.pdf
```
The tool searches, expands groups, resolves addresses.

**Direct address** — Claude (or a precise human) passes a pre-resolved address:
```
mail send alice@council.org cc dave@council.org subject "Q3 Update" body "..."
```
`searchContacts` detects a valid email and creates a synthetic contact. No search, no picker.

RFC 5322 format (`Alice Jones <alice@council.org>`) is also accepted and handled via the same synthetic contact path. This path was deliberately designed first — it is what enables Claude to pre-resolve and pass clean addresses.

---

## The council email scenario — clean case

The workflow Ken uses with Claude: send to a council group, cc a finance committee group, attach a report, body that needs care.

**What the human types:**
```
mail send council cc finance-committee subject "Q3 Update" body "Here is the Q3 update..." attach report.pdf
```

**What the tool should show before sending:**
```
To:  Alice Jones <alice@council.org>
     Bob Chen <bob@council.org>
     Carol Wu <carol@council.org>
     ... (8 total)
CC:  Dave Smith <dave@finance.org>
     Eve Park <eve@finance.org>
     ... (4 total)
Sub: Q3 Update
Att: report.pdf (2.1 MB)

Here is the Q3 update...

Send? (y/n)
```

The confirmation step IS the preparation step. The human sees everything assembled — group expansion, resolved names and addresses, body, attachments — before committing. No separate "prepare" command. No state between commands.

**What the confirmation must show (current plan is incomplete):**
- Full `to` address list (all resolved, not truncated)
- Full `cc` address list
- Subject
- Body preview (full if short; first N chars if long)
- Attachments with filename and size

Currently `formatSendConfirmation` only receives `[SendAddress]`. It needs the full `ComposedMessage` to show subject, body, and attachments.

---

## Dirty scenarios — current plan does not address these

### 1. Partial group failure

"council" expands to 8 members. Two have no email address.

Current plan: errors on any contact with no address. A single member without an email kills the entire send.

**Problem:** The human's intent was clearly to send to the council. Failing the whole operation because two contacts are incomplete is wrong. Skipping silently is also wrong.

**Open question:** Show unresolvable members in the confirmation and ask the human whether to proceed without them?

---

### 2. Picker fires before confirmation

If "finance-committee" in `cc` is ambiguous — matches a group AND a contact — the picker fires during resolution, before the human has seen whether the rest of the command parsed correctly. The human makes a choice without seeing the full picture.

**Problem:** If a later part of the command fails (missing attachment, another unresolvable contact), the picker interaction was wasted.

---

### 3. Mixed success across multiple queries

Three `cc` entries: one resolves clean, one triggers the picker, one finds nobody. The picker fires for the second, then the third errors. The human has already made a picker selection that is now discarded.

**This is the worst case.** Partial commitment followed by failure.

---

### 4. Group name collision

"council" matches both a contact group named "Council" and a contact named "Council Member." `searchContacts` returns contacts and expands groups. Which result wins? Is the group silently preferred? Does the picker show both?

---

### 5. Duplicate addresses

The treasurer is both a council member and explicitly CC'd. Their address appears in `to` (via group expansion) and `cc` (via direct query). Silent dedup? Error? Shown in confirmation?

---

## Proposed improvement: resolve-all-first

The common thread across the dirty scenarios is **partial commitment**: the human does work mid-command (picker selections) and then hits a failure that invalidates it.

**Proposal:** Resolve everything first — all queries, all group expansions, all address lookups. Collect all errors, all ambiguities, and all successes. Then present the full picture in one shot:

- If everything resolved cleanly → show confirmation, ask y/n.
- If there are ambiguities → show the full state with ambiguities called out, resolve them all at once (or fail with a complete list of what needs clarification).
- If there are hard errors (unresolvable contact, missing attachment) → show all errors together before the human does any picker work.

No picker fires until the human has seen the full state. No partial commitment.

This changes the architecture of `buildRecipients`: it becomes a two-phase function — collect results (including errors and ambiguities), then resolve ambiguities if the collection was otherwise successful.

---

## Open questions

1. What happens to partial group failure? Skip and warn, or block?
2. Does the picker belong in the confirmation view (showing ambiguities inline) or as a pre-confirmation step?
3. How does duplicate address deduplication work, and is it visible?
4. Group name collision — is the group always preferred, or does it go to the picker?
5. Body editing — for complex sends, the human may want to review/edit the body before confirming. Is that in scope for this feature or a future enhancement?

---

## Relationship to plan.md

This document is the input to Feature 014. Feature 013 is a pure type refactor (AddressEntry/SendResult → SendAddress) with no behavior changes. Everything below is deferred to 014.

---

## What Feature 013 defers to 014

### GetClearKit: InteractivePicker

Shared picker, injectable `InputReader` for testing. Generic over any item type. Accepts single number, comma-separated, range, or "all".

```swift
public struct InteractivePicker {
    public typealias InputReader = () -> String?
    private let read: InputReader

    public init(read: @escaping InputReader = { readLine() }) {
        self.read = read
    }

    public func pick<T>(
        from items: [T],
        label: (T) -> String,
        prompt: String
    ) -> [T]
}
```

Test cases: single number, comma-separated, range, "all", invalid re-prompts, out-of-range re-prompts.

---

### TextLib: TargetResolver — send flow redesign

Replace silent-first with full resolution using picker. Multi-recipient supported via group iMessage thread.

```swift
public func resolveTarget(
    query: String,
    store: any ContactStore,
    picker: InteractivePicker = InteractivePicker()
) async throws -> [SendAddress]
```

- Multiple contacts → picker for which contacts
- Single contact, multiple phones → picker for which phone
- No phone → error (no silent email fallback, #185 out of scope)

---

### TextLib: SendHandler — confirmation update

`formatSendConfirmation` takes `[SendAddress]`. Single recipient: one-line output. Multiple: one line per recipient.

---

### TextMessages: AppleMessageSender + MessagesClient — group send

`buildGroupScript(recipients:[String], message:String)` — iMessage group thread via AppleScript. Branch in `AppleMessageSender.send`: single recipient uses existing `sendViaMessages`, multiple uses `sendGroupViaMessages`. No partial success handling.

Test cases: two recipients both appear as buddies; special characters escaped via `appleScriptLiteral`.

---

### MailLib: RecipientResolver — send flow redesign

Replace silent-first `buildRecipients` with full resolution using picker. `to: String` (single query, matches `ComposedMessage.to`). Issue #186 will later change to `[String]` with comma splitting.

Two-level resolution: multiple contacts → picker; single contact, multiple emails → picker. Both levels use shared `InteractivePicker`.

Known design issues to resolve before implementing (see sections above):
- `async let` parallelism bug: `to` and `cc` must be sequential when either triggers the picker
- Two-level picking UX: consider erroring on multiple emails rather than second picker
- Picker fires before confirmation: see resolve-all-first proposal

---

### MailLib: SendHandler — confirmation update

`formatSendConfirmation` needs full `ComposedMessage` (not just `[SendAddress]`) to show subject, body preview, and attachments in addition to recipient list.

---

### `mail prepare` and `text prepare` commands

New commands that accept natural language input (names, group names, subject, body, attachments), resolve all recipients, show full confirmation, output and copy to clipboard the fully-formed `mail send` / `text send` command with RFC 5322 / E.164 addresses.

`send` becomes pure execution: accepts fully-specified addresses, no search, no picker. Both commands remain available to human and Claude actors.

Design decisions needed before spec:
- What does `send` do with an unambiguous single name query? Error or resolve?
- Partial group failure: skip and warn, or block?
- Duplicate address deduplication: silent or visible?
- Group name collision (group + contact with same name): group preferred or picker?
- iMessage file attachments: in scope for `text prepare` v1?
