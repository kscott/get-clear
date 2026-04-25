# Feature Specification: Shared Contact Resolution Library

**Feature Branch**: `012-shared-contacts-lib`  
**Created**: 2026-04-24  
**Status**: Draft  
**Input**: Shared contact resolution library with protocol-backed store abstraction, supporting Apple Contacts today and Google Contacts in the future. Mail and text tools currently each maintain their own contact types, loading code, and fuzzy matching — duplicating logic that belongs in one place. The contacts tool currently owns this logic but it needs to become a shared suite resource. The contacts tool itself becomes primarily a CRUD/find CLI backed by the same shared layer.

---

## Background

Three tools in the Get Clear suite need to resolve a person's name to a contact address: the text tool (resolves to a phone number), the mail tool (resolves to an email), and the contacts tool (finds and displays the person). Each tool currently maintains its own contact data type, its own code to load contacts from the system, and its own name-matching logic. The three implementations are nearly identical and have already diverged in small ways.

This duplication means any improvement to contact matching must be made three times, inconsistencies accumulate silently, and adding a new backend (Google Contacts) would require changes in three places instead of one.

---

## User Scenarios & Testing *(mandatory)*

The consumers of this library are the tool implementations (text, mail, contacts). Scenarios describe what the library returns, not what the calling tool does with that result. What gets displayed, sent, or acted upon is the tool's responsibility.

**Match quality** — the library matches a query against three fields: name, email, and phone. Partial matches are acceptable on all three — a query does not need to fully match a field value to return a result. Results are returned in order of how well the query matches: an exact match on a field outranks a partial match; a match on name outranks a match on email or phone. The library guarantees this ordering; the specific algorithm is an implementation detail.

### User Story 1 — Unique name query returns one ranked result (Priority: P1)

A tool calls the matching function with a name that matches exactly one contact. The library returns a list containing that contact's full record — name, all phone numbers, all email addresses. The tool picks the address it needs.

**Why this priority**: This is the core operation. Everything else depends on the library returning correct, complete records for an unambiguous query.

**Independent Test**: Call the matching function with a query that uniquely matches one contact; confirm exactly one Contact record is returned with correct fields.

**Acceptance Scenarios**:

1. **Given** the contacts list contains only "Alice Smith", **When** the matching function is called with "Alice", **Then** it returns a list containing exactly one Contact record representing Alice Smith.
2. **Given** the contacts list contains only "Alice Smith", **When** the matching function is called with "ALICE", **Then** it returns a list containing exactly one Contact record representing Alice Smith.

---

### User Story 2 — Ambiguous query returns all ranked matches (Priority: P1)

A tool calls the matching function with a name that matches more than one contact. The library returns all matching records, ranked by match quality. It does not pick one. The calling tool decides how to handle the ambiguity.

**Why this priority**: Silently picking the top match would cause tools to act on the wrong contact. The library must return all matches so ambiguity is visible and each tool can handle it appropriately for its context.

**Independent Test**: Call the matching function with a query that matches multiple contacts; confirm all matching records are returned in ranked order.

**Acceptance Scenarios**:

1. **Given** the contacts list contains "Alice Smith" and "Alan Jones", **When** the matching function is called with "Al", **Then** it returns a list with both Contact records.

---

### User Story 3 — Unknown query returns an empty list (Priority: P1)

A tool calls the matching function with a name that matches no contacts. The library returns an empty list. The tool decides what error to show.

**Why this priority**: An explicit empty result is the library's not-found contract. Error messaging belongs to the tool.

**Independent Test**: Call the matching function with a query that matches no contacts; confirm an empty list is returned.

**Acceptance Scenarios**:

1. **Given** no contact matches "Nobody", **When** the matching function is called with "Nobody", **Then** it returns an empty list.
2. **Given** any contacts list, **When** the matching function is called with an empty string, **Then** it returns an empty list.

---

### User Story 4 — Backend swap requires no changes to calling code (Priority: P2)

The Apple Contacts backend is replaced with a Google Contacts backend. All tools continue to call the same matching function with the same inputs and receive Contact records in the same structure. No tool code changes.

**Why this priority**: This validates the backend abstraction. If swapping backends requires touching tool code, the abstraction is incomplete.

**Independent Test**: Replace the backend implementation; confirm all matching function calls return correct results with zero changes outside the backend.

**Acceptance Scenarios**:

1. **Given** a different backend containing matching records is substituted, **When** the matching function is called, **Then** it returns Contact records in the same structure with no changes to the calling code.

---


---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The suite MUST provide a single shared contact resolution capability usable by mail, text, and contacts tools.
- **FR-002**: The shared library MUST define a single unified contact data type — no per-tool contact types.
- **FR-003**: The shared library MUST support matching queries against contact name, email, and phone fields, accepting partial matches on all three, and MUST return results ordered by match quality.
- **FR-004**: The shared library MUST be backend-agnostic: the source of contact data MUST be replaceable without changes to the library or its consumers.
- **FR-005**: Apple Contacts MUST be provided as the initial backend implementation.
- **FR-006**: The library MUST provide read and lookup operations only — it MUST NOT expose operations to create, modify, or delete contacts.
- **FR-007**: The shared library's business logic MUST NOT import platform contact frameworks — framework access belongs exclusively in the backend implementation.
- **FR-008**: The shared library MUST return the full list of matching contacts — it does not pick one. The calling tool decides how to handle single results, multiple results, and empty results for its own context.
- **FR-009**: The library MUST support exactly one active backend at a time — backends are mutually exclusive configurations, not simultaneous sources.

### Key Entities

- **Contact**: A record representing an identifiable entity — a person, business, or organization. Contains a name and zero or more values of each address type (phone, email). Multiple values per type are allowed. Physical addresses are outside this library's scope. All values are plain strings — no platform types.
- **ContactStore**: A backend that provides a list of contacts. The source of contacts is replaceable; the library does not depend on any specific implementation.
- **ContactQuery**: The input to a lookup — a string matched case-insensitively against contact fields (name, email, phone).

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The library operates against exactly one contact backend at a time.
- **SC-002**: Adding a new contact backend requires no changes to the library's matching logic.
- **SC-003**: The library returns the same ordered results for the same query against the same contact list on every call — results are deterministic.
