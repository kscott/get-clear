# Codebase Notes — 013-shared-send-address

Captured during spec review (2026-05-09). These are findings from codebase exploration
that inform the plan phase. The survey step may supplement these.

---

## What already exists in ContactKit

- `Contact` — name, emails, phones, company, identifier. All values are plain strings.
- `ContactGroup` — identifier + name. Already defined; `fetchGroups()` on ContactStore returns `[ContactGroup]`.
- `matchContacts(_ query: String, in contacts: [Contact]) -> [Contact]` — already searches name, email, company, and phone. Phone matching strips non-digit characters before comparing. Results ranked by match quality. Lives in `Sources/ContactKit/ContactMatching.swift`.
- `ContactStore` protocol — `fetchContacts(in:)` and `fetchGroups()`. Apple backend in `Sources/AppleContactKit/AppleContactStore.swift`.

`matchContacts` already covers multi-field search. The plan does not need to add field coverage — it needs to integrate group search alongside contact search.

---

## What needs to be deleted

| Thing | Location |
|---|---|
| `AddressEntry` struct | `mail-cli/Sources/MailLib/RecipientResolver.swift` |
| `SendResult` struct | `text-cli/Sources/TextLib/MessageSender.swift` |
| `requiresContactLookup()` | `mail-cli/Sources/MailLib/RecipientResolver.swift` and `text-cli/Sources/TextLib/TargetResolver.swift` |
| `resolveRecipients()` | `mail-cli/Sources/MailLib/RecipientResolver.swift` — replace with shared capability |
| `resolveTarget()` | `text-cli/Sources/TextLib/TargetResolver.swift` — replace with shared capability |

---

## Silent-first bugs to fix

Both resolvers silently take the first available result. Corrected by implementing the two-level disambiguation model.

- `mail-cli/Sources/MailLib/RecipientResolver.swift:57` — `matched.first` (first contact) + `first.emails.first?.value` (first email). Two silent choices in one statement.
- `text-cli/Sources/TextLib/TargetResolver.swift:33` — `contact.phones.first?.value` — first phone on matched contact.
- `text-cli/Sources/TextLib/TargetResolver.swift:36` — `contact.emails.first?.value` — silent email fallback when no phone. Tracked separately as #185.

---

## Canonicalization — what exists and where it needs to go

| Capability | Currently lives in | Needs to move to |
|---|---|---|
| Phone normalization to E.164 (`normalizePhone`) | `text-cli/Sources/TextLib/TargetResolver.swift` (or nearby) | Shared layer |
| RFC 5322 email formatting (`AddressEntry.formatted`) | `mail-cli/Sources/MailLib/RecipientResolver.swift:12–15` | Inside resolved-address type |
| Phone digit extraction for matching | `Sources/ContactKit/ContactMatching.swift:24–25` | Already shared — reuse for fallback detection and canonicalization |

---

## Direct-address detection — current implementations

Two separate, divergent implementations:

**MailLib** (`RecipientResolver.swift:24–27`):
- Checks: `q.contains("@") && !q.contains(" ")`
- Email-only — no phone detection

**TextLib** (`TargetResolver.swift:13–19`):
- Checks digit count (10 or 11 digits) for phone
- Checks `contains("@") && !contains(" ")` for email
- More complete than MailLib's version

The shared terminal fallback should be at least as capable as TextLib's version, and permissive on phone formats (any common formatting, strip non-digits before counting).

---

## Group resolution — current state

MailLib's `resolveRecipients()` handles groups via an exact group-name match checked before contact lookup. Groups are passed in as `[String: [AddressEntry]]` — a pre-built dictionary. This is tool-specific plumbing that the plan will need to redesign using `ContactGroup` from ContactKit.

TextLib has no group support today.

---

## Key file locations

```
mail-cli/Sources/MailLib/RecipientResolver.swift   — AddressEntry, requiresContactLookup, resolveRecipients, buildRecipients
mail-cli/Sources/MailLib/SendHandler.swift          — calls buildRecipients
text-cli/Sources/TextLib/TargetResolver.swift       — SendResult, requiresContactLookup, resolveTarget
text-cli/Sources/TextLib/MessageSender.swift        — SendResult definition (confirm)
text-cli/Sources/TextLib/SendHandler.swift          — calls resolveTarget
Sources/ContactKit/ContactMatching.swift            — matchContacts
Sources/ContactKit/ContactGroup.swift               — ContactGroup
Sources/ContactKit/ContactStore.swift               — ContactStore protocol
Sources/AppleContactKit/AppleContactStore.swift     — fetchGroups, fetchContacts, toContact boundary
```

---

## Implementation preferences

- **`sendable`** — the method on the resolved-address type that returns the canonical sending string should be named `sendable`. This is Ken's explicit preference for the final code.

---

## Design decisions made during spec

- **Always search first** — `requiresContactLookup` eliminated. Contact search runs unconditionally. Direct-address detection is the terminal fallback only.
- **Shared layer returns results; tool decides** — multiple contact records from a search is not inherently ambiguous. The user may have intended all of them. The shared layer never reduces or filters. The tool decides whether to process all, present a selection, or ask for confirmation.
- **Address retrieval accepts a list of contact records** — not one at a time. Returns a paired result: one entry per input contact record, each with that contact's resolved addresses of the requested type. Empty list for contacts with no addresses of the type — not silently dropped.
- **Group expansion produces a list of contact records** — no address-type work at this step. Same structure as any search result. Tool then calls address retrieval on that list.
- **Terminal fallback has two entry points** — search returns no contact records, or a specific contact record's address list is empty. Same fallback logic in both cases on the original input. Error message may reflect which entry point was reached.
- **Resolved-address type has two forms** (email, phone) with identical field labels regardless of form. Produces canonical sending string on demand.
- **Phone digit normalization is shared** — one implementation used by contact field matching, fallback detection, and canonicalization.
- **`ContactGroup` already exists** — plan builds on it; does not need to create it.
- **Issue #185** — text tool email fallback (when contact has no phone, silently tries email via Messages.app). Separate policy question, out of scope for this feature.
- **Issue #184** — resolver naming alignment (RecipientResolver vs TargetResolver). Out of scope; filed for future cleanup.
