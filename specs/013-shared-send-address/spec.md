# Feature Specification: Shared Recipient Resolution Foundation

**Feature Branch**: `013-shared-send-address`
**Created**: 2026-05-09
**Status**: Draft
**Input**: Introduce shared SendAddress type in ContactKit to unify mail and text recipient resolution (#167)

---

## Background

When a user types a recipient in the mail or text tools, both tools go through the same resolution process: search contacts, disambiguate if needed, and produce a resolved name and sendable address. Both tools also need to fall back to treating the input as a direct address when no contact is found.

Each tool currently has its own private type for the resolved output and its own private implementation of the fallback check. The two types are structurally identical and the two checks implement the same logic, but neither is aware of the other.

The duplication is benign today but becomes load-bearing when multi-recipient text (#68) ships. That feature will need the same group expansion logic that already exists in the mail tool's resolver. Without a shared foundation, a third copy of that logic gets written — and the three implementations will diverge silently over time.

---

## Scope and Boundaries

**Tool resolvers handle tool-specific concerns.** Each tool has its own resolver. A resolver takes the raw string a user typed as a recipient and produces a resolved address. The mail resolver handles multiple recipients, to/cc splits, and group expansion; the text resolver handles single-recipient targeting today and will grow when #68 ships. That tool-specific complexity is not shared.

**The shared contact layer provides what both resolvers need.** This includes the resolved-address type, the address-type selector, group expansion, the capability to retrieve resolved addresses for a list of contact records by type, and the terminal fallback check.

**The shared layer returns results. The tool decides what to do with them.** Multiple contact records returned by a search is not inherently ambiguous — the user may have intended all of them. Whether to process all, present a selection, or ask for confirmation is tool behavior, not shared layer behavior.

**Contact search always runs.** There is no pre-check on the input format — direct-address detection is the fallback of last resort, not a first-pass gate.

**Resolution flow — always search first, direct address is the shared terminal fallback.**

1. **Search** — always search contact records, including name, email, phone, company, and groups. No pre-check on the input format; the search runs unconditionally. The result is a list of contact records.

2. **Group expansion** — if the search matched a group, the shared layer expands it to the full list of member contact records. No address-type work is done at this step. The result is a list of contact records, identical in shape to what a direct search returns.

3. **Address retrieval** — the tool passes a list of one or more contact records and a requested address type to the shared layer. The shared layer returns a paired result: one entry per input contact record, each carrying that contact's resolved addresses of the requested type. A contact record with no addresses of the requested type has an empty address list in the result — it is not silently dropped. The tool decides what to do with each entry.

4. **Terminal fallback** — reached via two distinct entry points: the search returned no matching contact records, or a specific contact record's address list for the requested type is empty. In both cases, the same fallback logic runs on the original input. If the input looks like a valid email or phone number (permissive; phone accepted in any common format) → produce a resolved address directly and canonicalize. If not → not found error, with a message that reflects which entry point was reached where possible.

**Existing silent-choice bugs to fix as part of this feature.** Both current resolvers silently pick the first available contact record and the first available address rather than returning the full result set to the tool. These are trust-eroding bugs — a user who has multiple contacts named "alice" or a contact with multiple email addresses will get a result chosen without their knowledge. Correcting this means returning the full result set and letting the tool decide. (#185 tracks the related text tool email fallback, which is a separate policy question.)

---

## User Scenarios & Testing *(mandatory)*

Scenarios describe what the shared foundation provides to the tool resolvers, not what the tools do with it. Displaying, sending, or acting on a resolved address is the tool's responsibility.

### User Story 1 — Resolution returns a name and address (Priority: P1)

A tool resolves a recipient — whether from a contact lookup or a direct address — and receives a value that holds both a display name and a sendable address. The tool does not need to distinguish how the resolution happened; it gets the same shape either way.

**Why this priority**: This is the foundational contract. The shared type must be useful to both mail (email addresses) and text (phone numbers) without either knowing about the other's address format.

**Independent Test**: Perform a resolution that ends in a contact match; perform one that ends with a direct address input. Confirm both return the same structure with a name and an address.

**Acceptance Scenarios**:

1. **Given** a contact "Alice Smith" with email "alice@example.com", **When** the mail tool resolves "Alice", **Then** the result carries display name "Alice Smith" and address "alice@example.com".
2. **Given** a contact "Bob Jones" with phone "+14155550100", **When** the text tool resolves "Bob", **Then** the result carries display name "Bob Jones" and address "+14155550100".
3. **Given** the input "alice@example.com" matches no contact, **When** the terminal fallback runs, **Then** the result carries the input as both name and address.

---

### User Story 2 — Search always returns a list of contact records (Priority: P1)

Search handles all input forms and always returns a list of contact records. The list may contain real contact records, a synthetic contact record constructed from a valid direct address, or group member records. An input that matches nothing and does not look like a valid address returns an empty list. The caller always receives the same type regardless of what was typed. Search knows nothing about address types — it returns all matching contact records regardless of what addresses those records carry. Filtering by address type is address retrieval's responsibility, not search's.

**Why this priority**: Consistent return type is what makes address retrieval uniform. If search returned different types for different inputs, address retrieval would need to handle multiple input forms.

**Independent Test**: Pass each of the five input forms to search. Confirm all return a list of contact records.

**Acceptance Scenarios**:

1. **Given** the input matches no contact record and does not look like a valid email or phone, **When** search runs, **Then** it returns an empty list.
2. **Given** the input matches no contact record but is a valid email or phone, **When** search runs, **Then** it returns a list containing one synthetic contact record with the input in the appropriate address field.
3. **Given** the input matches a named group, **When** search runs, **Then** it returns the full list of member contact records.
4. **Given** the input matches one or more contact records, **When** search runs, **Then** it returns all of those contact records — none are dropped or reduced.
5. **Given** the input matches both a named group and one or more individual contact records, **When** search runs, **Then** it returns a single flat list containing the group's member contact records and the individually matched contact records.
6. **Given** "alice" matches Alice Smith and Alice Jones, **When** search runs, **Then** both contact records are returned — the shared layer does not reduce to one.

---

### User Story 3 — Search matches contacts across all fields (Priority: P1)

A user may type a name, a company, an email address, a phone number, or a group name as a search term. Search finds contact records that match on any of those fields — not just name. The caller does not specify which field to search; the search covers all of them. Phone matching strips non-digit characters before comparing, so format differences between the search term and the stored value do not prevent a match.

**Why this priority**: Name-only search requires the user to remember exactly how a contact is stored. Matching on email, phone, company, and group name means any recognizable identifier finds the right contact record.

**Independent Test**: Search using each field type in turn. Confirm a contact record is returned in all cases.

**Acceptance Scenarios**:

1. **Given** a contact with name "Alice Smith" and email "alice@example.com", **When** search is called with "alice@example.com", **Then** it returns that contact record — matched by email field.
2. **Given** a contact with name "Bob Jones" and phone stored as "+12105555555", **When** search is called with "210.555.5555", **Then** it returns that contact record — non-digit characters stripped from both search term and stored value before comparing.
3. **Given** a contact with name "Bob Jones" and phone stored as "(210) 555-5555", **When** search is called with "210.555.5555", **Then** it returns that contact record — both reduce to the same digit string regardless of formatting.
4. **Given** a contact with company "Acme Corp", **When** search is called with "acme", **Then** it returns that contact record — matched by company field.
5. **Given** a contact with name "Alice Smith", **When** search is called with "alice", **Then** it returns that contact record — matched by name field.
6. **Given** a group named "Family", **When** search is called with "family", **Then** it returns the group's member contact records.

---

### User Story 4 — Address retrieval accepts a list of contact records and returns a complete paired result (Priority: P1)

The tool passes a list of contact records and an explicitly specified address type to the shared layer. The shared layer returns one entry per input contact record, each paired with that contact's resolved addresses of the requested type. All addresses are returned — none are reduced. A contact record with no addresses of the requested type is included with an empty address list — it is not silently dropped. The tool decides what to do with every entry.

**Why this priority**: A batch call covering a group with hundreds of members must not require the tool to call the shared layer once per contact record. The paired result preserves the contact-address association so the tool can report on each entry individually. Silent omission produces wrong results without any signal.

**Independent Test**: Pass a list of contact records with varying address coverage — some with multiple addresses, some with one, some with none — and a requested type. Confirm one entry is returned per input contact record, all addresses present, empty lists included.

**Acceptance Scenarios**:

1. **Given** a list containing Alice Smith (3 emails) and Bob Jones (1 email), **When** address retrieval is called with type email, **Then** the result contains one entry for Alice with 3 resolved addresses and one entry for Bob with 1 resolved address.
2. **Given** a list containing Alice Smith (3 emails) and Alice Jones (no email), **When** address retrieval is called with type email, **Then** the result contains one entry for Alice Smith with 3 resolved addresses and one entry for Alice Jones with an empty list — Alice Jones is not dropped.
3. **Given** a list containing one contact record with phone stored as "(415) 555-0100", **When** address retrieval is called with type phone, **Then** the result contains one entry with one resolved address whose canonical sending string is "+14155550100".
4. **Given** a list of one hundred contact records, **When** address retrieval is called, **Then** the result contains one hundred entries — one per input contact record.

---

### User Story 5 — Both tools produce identical results for identical inputs (Priority: P1)

When the same input is passed to both tool resolvers, the resolution outcome and the canonical sending string are identical. The shared layer enforces this — there are no per-tool variations in matching, canonicalization, or fallback behavior.

**Why this priority**: Divergence between tools is invisible to users and accumulates silently. Shared logic is the only enforcement mechanism.

**Independent Test**: Pass the same input — including borderline cases like unusual phone formats — to both resolvers. Confirm identical resolved addresses and identical canonical sending strings.

**Acceptance Scenarios**:

1. **Given** the input "(415) 555-0100" matches no contact, **When** both tool resolvers apply the terminal fallback, **Then** both produce a resolved address with the same canonical sending string.
2. **Given** the same contact exists in both tool contexts, **When** both resolvers are called with the same query, **Then** both return a resolved address with the same name and canonical sending string.

---

### User Story 6 — Resolved address produces its own canonical sending string (Priority: P1)

A contact may have phone numbers stored in any format. The sending layer for each tool expects a specific format — RFC 5322 for email, E.164 for phone. The resolved address bridges that gap: it accepts raw contact store values and produces the correct canonical string for its type when asked. The caller passes that string directly to the sending layer. It does not know the format rules, and it does not assemble the string.

**Why this priority**: If each tool assembles the sending string itself, the format rules are duplicated and will diverge. One place defines what "sendable" means for each address type.

**Independent Test**: Construct a resolved address from a phone stored as "(415) 555-0100" and another from the same number stored as "415.555.0100". Confirm both produce the same canonical sending string.

**Acceptance Scenarios**:

1. **Given** a phone resolved address constructed from "(415) 555-0100", **When** the canonical sending string is requested, **Then** it returns "+14155550100".
2. **Given** a phone resolved address constructed from "415.555.0100", **When** the canonical sending string is requested, **Then** it returns the same value as scenario 1.
3. **Given** an email resolved address with name "Alice Smith" and address "alice@example.com", **When** the canonical sending string is requested, **Then** it returns "Alice Smith <alice@example.com>".
4. **Given** a direct-address input "alice@example.com" with no contact match, **When** a resolved address is constructed from it, **Then** the canonical sending string returns "alice@example.com" with no name prefix.

---

### User Story 7 — Multi-recipient text can reuse mail's group resolution (Priority: P2)

When multi-recipient text ships (#68), the text tool can use the same group-expansion logic that the mail tool already has, built on the shared foundation. No third copy of recipient resolution is written.

**Why this priority**: The shared foundation's value compounds when #68 lands. If it isn't in place first, #68 creates the divergence the shared layer is meant to prevent.

**Independent Test**: When #68 is implemented, confirm the text tool's group resolution delegates to shared logic rather than reimplementing it.

**Acceptance Scenarios**:

1. **Given** a comma-separated list of recipients, **When** the text tool resolves them, **Then** each recipient is resolved using the same logic as a mail tool multi-recipient resolution.

---

### Edge Cases

- **Multiple contacts returned, one has no address of the requested type** — e.g., "alice" returns Alice Smith (3 emails) and Alice Jones (phone only, mail tool). Address retrieval returns Alice Smith's emails and an empty list for Alice Jones. The tool decides what to do with each entry.
- **Single contact, multiple addresses of the requested type** — e.g., Alice Smith has 3 email addresses. Address retrieval returns all 3. The tool decides which to use.
- **Single contact, exactly one address of the requested type** — address retrieval returns one resolved address. The tool uses it.
- **Search returns empty, input is not a valid address** — no contact matched and input is not a recognizable email or phone. Search returns an empty list. Tool surfaces not found.
- **Search returns empty, input is a valid address** — no contact matched but input is a valid email or phone. Search constructs a synthetic contact record and returns it. Address retrieval produces a resolved address from it.
- **Input looks like an address and matches a contact** — contact match takes precedence. No synthetic contact is constructed.
- **Direct address detection false positive** — an input that contains "@" but is not a valid email (e.g., a name). The detection rule must be conservative: prefer not-found over misidentifying a name as a direct address.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The suite MUST provide a single shared resolved-address type usable by both the mail and text resolution layers.
- **FR-002**: The resolved-address type MUST carry a display name and a sendable address — no tool-specific fields.
- **FR-003**: When search produces no matching contact records, the shared layer MUST check whether the original input is a valid email or phone number using the direct address detection rules. If valid, the shared layer MUST construct a synthetic contact record with the input in the appropriate address field and return it as the search result. If not valid, the shared layer MUST return an empty list. This check MUST be defined once in the shared layer; per-tool implementations MUST be deleted.
- **FR-004**: Both the mail and text resolution layers MUST produce the shared resolved-address type as their output — tool-private equivalents MUST be deleted.
- **FR-005**: The resolved-address type, address-type selector, and all shared resolution capabilities MUST live in the shared contact layer — not in any tool-specific code.
- **FR-006**: The resolved-address type MUST be address-format-agnostic — it MUST represent an email address and a phone number with equal fidelity, without encoding mail-vs-text distinctions into its structure.
- **FR-007**: The shared layer MUST support group expansion — when a search term matches a named group, the group MUST be expanded to the full list of its member contact records. No address-type work is performed at this step. The result is a list of contact records in the same structure as any other search result.
- **FR-008**: The resolved-address type MUST produce a canonical, target-independent sending string on demand — RFC 5322 format for email, E.164 for phone. Callers MUST use this produced string; they MUST NOT assemble it themselves.
- **FR-009**: The canonical format rules for each address type MUST be defined once inside the resolved-address type — no per-tool formatting or normalization logic.
    - **FR-009a**: The logic for normalizing phone digits — stripping non-digit characters to compare or normalize a phone string — MUST be defined once in the shared layer and used consistently by contact field matching, direct address detection, and address canonicalization.
- **FR-010**: Raw contact store values MUST be accepted as input when constructing a resolved address; the canonical form is produced internally. Callers MUST NOT pre-normalize values before passing them in.
- **FR-011**: The shared layer MUST provide a capability that accepts a list of one or more contact records and a requested address type and returns a paired result — one entry per input contact record, each carrying that contact's resolved addresses of the requested type. A contact record with no addresses of the requested type MUST appear in the result with an empty address list — it MUST NOT be silently omitted. The caller MUST specify the address type explicitly; the shared layer MUST NOT infer it.
    - **FR-011a**: The address type selector MUST represent a fixed, closed set of valid values — email and phone. No other address types are in scope for this feature. An invalid address type MUST NOT be expressible.
- **FR-012**: The shared layer MUST NOT reduce or filter the result set based on count. Returning the full result — all matching contact records, all addresses per contact — is the shared layer's responsibility. Decisions about what to do with multiple results are the tool's responsibility.
- **FR-013**: When search returns an empty list, the error surfaced to the tool MUST indicate that no contact record was found and the input was not a recognizable address. When address retrieval returns an empty address list for a contact record, the error MUST indicate that the contact was found but has no address of the requested type. These are distinct outcomes and MUST produce distinct messages.

### Key Entities

- **SendAddress**: The resolved-address type. Has two distinct forms — one for email, one for phone — but regardless of form, both carry the same two fields under the same labels: a display name and an address value. A caller reads either form identically; the form does not change the interface. Produces a canonical sending string on demand: RFC 5322 format for email, E.164 for phone. Raw values go in; canonical form comes out. Callers never assemble the sending string themselves. Display name is resolved at construction time using this hierarchy: contact name if present, otherwise company name, otherwise this specific address value. Each resolved address applies this rule independently — when a contact has no name or company, each `SendAddress` produced from it uses its own address value as its display name. The canonical sending string is aware of this: for email, when a name or company is present it produces `"Name <address>"` or `"Company <address>"`; when the display name equals the address value (no name or company), it produces a bare address rather than the redundant `"address <address>"` form.
- **AddressType**: The address-type selector. A fixed, closed set with exactly two values — email and phone. Passed explicitly by the caller when requesting addresses from the shared layer. The tool's domain knowledge (mail needs email, text needs phone) is expressed at the call site, not inferred by the shared layer.
- **Direct address**: An input that is recognized as a sendable address (email or phone) without matching a contact record. Used to construct a synthetic contact record when search produces no match. The recognition rules are defined once in the shared layer:
    - **Email**: contains `@` with a non-empty local part before it and a non-empty domain after it, and no spaces. Reference: RFC 5322.
    - **Phone**: when all non-digit characters are stripped, the remaining digit count falls within a valid range (10–15 digits). 10 digits is the primary case (NANP). 11–15 digits accommodates country codes (1–3 digits) followed by a subscriber number. Reference: NANP, E.164.

- **Phone number rules** — defined once in the shared layer, applied consistently across detection, matching, and canonicalization:
    - **Detection**: strip all non-digit characters; if the digit count is 10–15, treat as a phone number.
    - **Matching**: compare digit strings by suffix — the search term's digit string must match as a trailing substring of the stored value's digit string. A 10-digit search term matches any stored number whose last 10 digits are identical, regardless of country code prefix.
    - **Canonicalization**: a 10-digit input is assumed to be a NANP number and canonicalized to E.164 by prepending +1. An input that already includes a country code indicator (starts with + or has 11–15 digits) is used as provided, formatted to E.164. The canonicalization rule is designed to be extensible — the +1 assumption for 10-digit numbers is the primary case, not a hard constraint on future international support.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The suite contains exactly one resolved-address type — tool-private equivalents are deleted.
- **SC-002**: The direct address detection and synthetic contact construction logic is defined in exactly one place — no per-tool copies exist.
- **SC-003**: The same input produces the same list of contact records regardless of which tool calls search — matching, group expansion, and direct address detection behave identically. Differences in resolved addresses between tools are expected and correct, as each tool requests a different address type from the same contact records.
- **SC-004**: When #68 is implemented, no new copy of group-resolution logic is written — the text tool delegates to the shared foundation.
