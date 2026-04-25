# Research: Shared Contact Resolution Library

No external unknowns — all three contact implementations exist in the repo and can be inspected directly.

---

## Decision: Where the shared Contact type lives

**Decision**: `Sources/GetClearKit/Contact.swift` + `ContactStore.swift`

**Rationale**: The constitution says "GetClearKit first." The test: could a new sixth tool get contact lookup by importing GetClearKit alone? Yes — the Contact type, ContactStore protocol, and matchContacts function must all be in GetClearKit for this to be true.

**Alternatives considered**: ContactsLib as the shared layer. Rejected — ContactsLib is contacts-cli's private library. Other tools importing contacts-cli code would violate the tool boundary and create an implicit ownership dependency.

---

## Decision: Where AppleContactStore lives

**Decision**: New `Sources/ContactKit/` package target (framework boundary)

**Rationale**: Three CLIs (contacts-bin, mail-bin, text-bin) already link the Contacts framework. A single shared target containing `AppleContactStore` avoids duplicating the loading code. Placing it in `Sources/` at the monorepo root (parallel to `Sources/GetClearKit/`) signals that it's a shared suite resource, not owned by any single tool.

**Alternatives considered**: Each tool's CLI target maintains its own loading code. Rejected — that's exactly the duplication this feature is removing. Placing AppleContactStore under contacts-cli/. Rejected — architecturally wrong; mail and text would import a contacts-cli target.

---

## Decision: Contact type shape

**Decision**: `Contact` mirrors `ContactRecord` from ContactsLib (labeled tuples, company field) — not the simpler `MailContact`/`MessageContact` shapes.

**Rationale**: `ContactRecord` is the most complete existing type. Labeled tuples (`[(label: String, value: String)]`) preserve display metadata that contacts-cli needs. `company` is used by the matching algorithm (score 4/5) and contacts-cli display. Stripping these would be a regression.

**Alternatives considered**: Plain `[String]` for emails and phones (MailContact/MessageContact style). Rejected — contacts-cli uses labels for display and the matching algorithm uses company. We'd have to re-add them later.

---

## Decision: matchContacts in MailLib

**Decision**: `resolveRecipients` delegates step 3 (fuzzy contact match) to `matchContacts` from GetClearKit instead of maintaining its own score function.

**Rationale**: The ContactsLib version of `matchContacts` is more complete (includes company and phone matching). MailLib's local score function was a subset duplicate. Since MailLib now depends on GetClearKit anyway (for the Contact type), using the shared function eliminates a ~15-line duplicate.

**Alternatives considered**: Keep MailLib's local score function and just update types. Rejected — no-duplication rule applies even when the duplication is pre-existing.

---

## Decision: toContact() visibility

**Decision**: `toContact(_ c: CNContact) -> Contact` is `public` in ContactKit.

**Rationale**: ContactsCLI needs to go from `CNContact` to `Contact` for its write-side bridge (finding the `CNContact` that matches a query result). If `toContact` is internal to ContactKit, ContactsCLI can't use it and would have to re-implement the conversion. Public is the right call — it's part of ContactKit's API surface.

**Alternatives considered**: Internal to ContactKit; ContactsCLI re-implements conversion inline. Rejected — duplication.

---

## Decision: cleanLabel visibility

**Decision**: `internal` in ContactKit, tested via `@testable import ContactKit` in ContactKitTests.

**Rationale**: `cleanLabel` is an implementation detail of Apple's CNLabel format. It's not useful to callers of ContactKit — `toContact` handles it internally. Making it public would expose Apple-specific string formatting as part of the library's API. Internal + testable via @testable is the right scope.

**Alternatives considered**: Staying public in ContactsLib. Rejected — ContactsLib shouldn't know about CNLabel format; that knowledge belongs at the framework boundary.

---

## Decision: addressField removed from Contact

**Decision**: `addressField` (the "Name <email>" formatter from ContactRecord) is not ported to Contact. `exportAddresses` in ContactsLib inlines the formatting.

**Rationale**: "Name <email>" is a mail header format. Putting it on the base Contact type makes a shared data type aware of a mail-specific convention. `exportAddresses` is the only caller; it inlines one line.

**Alternatives considered**: Keep it on Contact. Rejected — violation of the "Contact is data, not formatting" principle.
