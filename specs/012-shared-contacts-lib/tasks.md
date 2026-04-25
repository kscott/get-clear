# Tasks: Shared Contact Resolution Library

**Input**: Design documents from `/specs/012-shared-contacts-lib/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel with other [P] tasks in the same phase
- **[Story]**: Which user story this task belongs to
- All file paths are relative to monorepo root

---

## Phase 1: Setup

**Purpose**: Create directories and update Package.swift before any source files are written.

- [ ] T001 Create directory Sources/ContactKit/ for the new framework-boundary target
- [ ] T002 Create directory Tests/ContactKitTests/ for CleanLabel tests
- [ ] T003 Update Package.swift: add ContactKit target (deps: GetClearKit, links Contacts), ContactKitTests test target, add GetClearKit dep to MailLib and TextLib, add ContactKit dep to contacts-bin mail-bin text-bin

---

## Phase 2: Foundational — Contact Type

**Purpose**: The `Contact` struct is the dependency of every downstream task. Nothing else can be written until this type exists in GetClearKit.

**⚠️ CRITICAL**: All US1–US4 work depends on this phase being complete first.

- [ ] T004 Create Sources/GetClearKit/Contact.swift — Contact struct with name, emails [(label,value)], phones [(label,value)], company; computed primaryEmail and primaryPhone
- [ ] T005 Create Tests/GetClearKitTests/ContactSpec.swift — QuickSpec testing primaryEmail and primaryPhone accessors (present and absent cases)

**Checkpoint**: `swift build` must succeed before Phase 3.

---

## Phase 3: User Stories 1, 2, 3 — Contact Matching (Priority: P1) 🎯 MVP

**Goal**: A caller passes a `[Contact]` list and a query string; the library returns ranked matches, all matches, or an empty list — never picks one.

**Independent Test**: Instantiate a `[Contact]` array inline (no framework needed), call `matchContacts`, assert count and order.

- [ ] T006 [US1] Create Sources/GetClearKit/ContactStore.swift — ContactStore protocol (async throws contacts()) + matchContacts free function (copy algorithm from ContactsLib/Matching.swift, update ContactRecord → Contact)
- [ ] T007 [US1] Create Tests/GetClearKitTests/ContactStoreSpec.swift — QuickSpec with describe("matchContacts") migrated from ContactsLibTests/MatchingSpec.swift: name/email/company/phone matching, sort order, empty query, unmatched query, case-insensitivity

**Checkpoint**: `swift test --filter ContactStoreSpec` must pass.

---

## Phase 4: User Story 4 — Backend Abstraction (Priority: P2)

**Goal**: Swap the contact source without changing any tool code. Apple Contacts is the first implementation.

**Independent Test**: Construct `AppleContactStore` in a CLI, call `contacts()`, confirm `[Contact]` is returned. (Requires device permission — verified by `swift build` success and ContactKitTests passing.)

- [ ] T008 [US4] Create Sources/ContactKit/AppleContactStore.swift — public final class AppleContactStore: ContactStore; public func toContact(_ c: CNContact) -> Contact; internal func cleanLabel(_ raw: String) -> String; fetch keys: givenName, familyName, organizationName, emailAddresses, phoneNumbers
- [ ] T009 [P] [US4] Create Tests/ContactKitTests/CleanLabelSpec.swift — @testable import ContactKit; QuickSpec testing cleanLabel: strips _$!<...>!$_ wrapper, lowercases plain strings, handles empty string
- [ ] T010 [P] [US4] Create Tests/ContactKitTests/SpyContactStoreSpec.swift — QuickSpec verifying the SpyContactStore pattern compiles and returns pre-loaded contacts (documents the test double for all downstream test authors)

**Checkpoint**: `swift build` and `swift test --filter ContactKitTests` must pass.

---

## Phase 5: Polish — Migrate Tool Consumers

**Purpose**: Delete per-tool contact types and loading code; wire all three tools to the shared layer.

Contacts-cli, text-cli, and mail-cli migrations are independent of each other — [P] tasks across tool boundaries can be run in any order or simultaneously.

### 5A — ContactsLib (contacts-cli library layer)

- [ ] T011 [P] Update contacts-cli/Sources/ContactsLib/Matching.swift — remove ContactRecord struct, remove matchContacts func, remove cleanLabel func, remove addressField computed property; update exportAddresses to take [Contact] and inline "Name <email>" formatting; add import GetClearKit
- [ ] T012 [P] Update contacts-cli/Sources/ContactsLib/ContactFormatter.swift — ContactRecord → Contact in cardLines(for:) signature; field access unchanged (same shape)

### 5B — ContactsCLI (contacts-cli framework boundary)

- [ ] T013 Update contacts-cli/Sources/ContactsCLI/ContactConversion.swift — remove toRecord() (replaced by toContact() from ContactKit); add import ContactKit; update cnContact(named:in:) to use toContact() + matchContacts() from GetClearKit; keep allContacts(), group(), applyChanges()
- [ ] T014 Update contacts-cli/Sources/ContactsCLI/ListCommand.swift — replace toRecord(_:) calls with toContact(_:) (2 call sites at lines ~21 and ~35)

### 5C — TextLib + TextCLI

- [ ] T015 [P] Update text-cli/Sources/TextLib/PhoneNormalizer.swift — remove MessageContact struct; update resolveSendTarget parameter to [Contact]; update phone access to contact.phones.first?.value; update email access to contact.emails.first?.value; add import GetClearKit
- [ ] T016 [P] Delete text-cli/Sources/TextCLI/ContactsLoader.swift — file is replaced entirely by AppleContactStore
- [ ] T017 Update text-cli/Sources/TextCLI/main.swift — remove import Contacts; remove loadMessageContacts call; add import ContactKit; construct AppleContactStore and call contacts() in async context; pass [Contact] to handlers
- [ ] T018 [P] Update text-cli/Sources/TextCLI/SendCommand.swift — [MessageContact] → [Contact] in handleSend signature; body unchanged (resolveSendTarget handles Contact)
- [ ] T019 [P] Update text-cli/Sources/TextCLI/OpenCommand.swift — [MessageContact] → [Contact] in handleOpen signature; body unchanged

### 5D — MailLib + MailCLI

- [ ] T020 [P] Update mail-cli/Sources/MailLib/RecipientResolver.swift — remove MailContact struct; contacts param: [MailContact] → [Contact]; add import GetClearKit; replace local score function in step 3 with matchContacts() call; update email value access to .value on labeled tuples; update primaryEmail via contact.primaryEmail
- [ ] T021 [P] Update mail-cli/Sources/MailLib/SendCommand.swift — contacts param: [MailContact] → [Contact] in runSend signature
- [ ] T022 Update mail-cli/Sources/MailCLI/SendCommand.swift — remove private loadContacts() function and its keysToFetch; add import ContactKit; construct AppleContactStore(store: contactStore) and await contacts(); Contacts import stays (loadGroups still uses CNContactStore directly)

### 5E — Test migrations

- [ ] T023 [P] Update contacts-cli/Tests/ContactsLibTests/MatchingSpec.swift — remove describe("matchContacts") block (moved to ContactStoreSpec), remove describe("ContactRecord") block (moved to ContactSpec), remove describe("cleanLabel") block (moved to CleanLabelSpec); keep describe("exportAddresses") and update ContactRecord fixture construction to Contact(name:emails:phones:company:)
- [ ] T024 [P] Update contacts-cli/Tests/ContactsLibTests/ContactFormatterSpec.swift — makeContact() return type ContactRecord → Contact; ContactRecord(...) → Contact(...) throughout; all assertions unchanged
- [ ] T025 [P] Update text-cli/Tests/TextLibTests/PhoneNormalizerSpec.swift — MessageContact(name:phones:emails:) → Contact(name:emails:phones:company:); labeled tuple syntax for emails/phones: [("", "alice@example.com")]; add company: "" argument
- [ ] T026 [P] Update mail-cli/Tests/MailLibTests/RecipientResolverSpec.swift — MailContact(name:emails:) → Contact(name:emails:phones:company:); labeled tuple syntax for emails; add phones: [], company: ""; resolveRecipients/buildRecipients calls now take [Contact]

---

## Final: Validation

- [ ] T027 Run swift build and confirm zero errors and zero new warnings
- [ ] T028 Run swift test and confirm all tests pass; report total pass count

---

## Dependencies

```
T001 → T002 → T003 → T004 → T005
                       ↓
                      T006 → T007
                       ↓
               T008 → T009 [P]
                       ↓  → T010 [P]
               ┌───────┴──────────────────────┐
              T011[P]  T013         T015[P]    T020[P]
              T012[P]   ↓           T016[P]    T021[P]
                       T014          ↓         T022
                        ↓           T017
                     T023[P]        T018[P]   T023[P]
                     T024[P]        T019[P]   T026[P]
                                   T025[P]
                                       ↓
                                      T027 → T028
```

## Parallel Execution Examples

**Phase 5 across tools** (all safe to run in any order after T010):
```
T011, T012        (ContactsLib — different files)
T013 → T014       (ContactsCLI — sequential, T014 uses toContact from T013's ContactConversion)
T015, T016        (TextLib files — different files)
T020, T021        (MailLib files — different files)
T017, T018, T019  (TextCLI — T018/T019 parallel, then T017)
T022              (MailCLI — independent of TextCLI work)
```

**Test migrations** (all [P] after their source files are updated):
```
T023, T024, T025, T026  (all different test files, all depend only on their own source file)
```

## Implementation Strategy

- **MVP (Phases 1–4)**: Delivers a working shared layer with full test coverage. The three tools still use their old types but the new layer is ready and verified.
- **Full delivery (Phase 5)**: Migrates all three tools to the shared layer, deletes the per-tool types, and verifies end-to-end with `swift test`.
- The MVP is independently useful — AppleContactStore can be tested and the protocol proven before touching any tool code.
