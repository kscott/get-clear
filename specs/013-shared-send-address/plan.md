# Implementation Plan: Shared Recipient Resolution Foundation

**Branch**: `013-shared-send-address` | **Date**: 2026-05-10 | **Spec**: [spec.md](spec.md)  
**Input**: Feature specification from `specs/013-shared-send-address/spec.md`

## Summary

`AddressEntry` (MailLib) and `SendResult` (TextLib) are structurally identical private types. This plan introduces `SendAddress` in ContactKit as the single unified resolved-address type, moves phone normalization into ContactKit, and replaces both resolvers' private type references with calls to shared `searchContacts` and `resolveAddresses` functions. No user-visible behavior changes — the silent-first bugs in both resolvers are known and deferred to Feature 014, which redesigns the send flow with `mail prepare` / `text prepare` commands and a fully interactive resolution pipeline.

## Technical Context

**Language/Version**: Swift 5.9 (swift-tools-version: 5.9)  
**Primary Dependencies**: Quick + Nimble (testing); ContactKit, GetClearKit (shared suite libraries)  
**Storage**: N/A — reads from ContactStore protocol; no writes in this feature  
**Testing**: Quick + Nimble via `swift test`; ContactKit tests need no framework permissions  
**Target Platform**: macOS 14+  
**Project Type**: Library targets within monorepo (ContactKit additions; MailLib + TextLib refactors)  
**Performance Goals**: N/A — contact fetch is unchanged; group expansion retains `withThrowingTaskGroup` parallelism  
**Constraints**: ContactKit must remain a pure Swift target (no framework imports); `normalizePhone` moves there intact  
**Scale/Scope**: 2 tool resolvers type-migrated; 2 private types deleted; 4 new types + functions added to ContactKit; no new commands; no behavior changes

## Constitution Check

| Rule | Status | Notes |
|------|--------|-------|
| GetClearKit first | ✓ N/A | SendAddress is domain-specific; belongs in ContactKit per 2026-04-25 decision |
| No framework imports in Lib | ✓ PASS | All new code is pure Foundation; ContactKit has no framework imports |
| No duplication | ✓ PASS | Two private types → one shared type; two detection impls → one |
| Add/remove ship together | ✓ N/A | Library refactor; no new commands |
| Tests ship with code | ✓ PASS | Four new ContactKit spec files; five existing specs updated |
| No flags | ✓ N/A | No CLI changes |
| Backend substitution test | ✓ PASS | SendAddress in shared layer means a GmailClient can use the same mail handler signatures |

## Project Structure

### Documentation (this feature)

```text
specs/013-shared-send-address/
├── spec.md              # Feature specification
├── plan.md              # This file
├── data-model.md        # Phase 1 output
├── contracts/
│   └── contactkit-api.md  # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks — not created here)
```

### Source Code

New files marked **NEW**. Deleted files marked **DELETE**. All others are updates.

```text
Sources/ContactKit/
  SendAddress.swift          NEW  — SendAddress, AddressType, ResolvedAddress
  PhoneNormalization.swift   NEW  — phoneDigits(), normalizePhone() (moved from TextLib, internal)
  RecipientSearch.swift      NEW  — searchContacts() + internal helpers
  AddressRetrieval.swift     NEW  — resolveAddresses(for:type:)
  ContactMatching.swift      UPDATE — use phoneDigits() for digit stripping

Tests/ContactKitTests/
  ContactKitSendAddressSpec.swift        NEW
  ContactKitRecipientSearchSpec.swift    NEW
  ContactKitAddressRetrievalSpec.swift   NEW
  ContactKitPhoneNormalizationSpec.swift NEW  (migrated from TextLibTests)

mail-cli/Sources/MailLib/
  RecipientResolver.swift    UPDATE — delete AddressEntry; migrate type references to SendAddress;
                                      interaction behavior unchanged (silent-first bugs deferred to 014)
  MailClient.swift           UPDATE — OutboundEmail.to/cc: [AddressEntry] → [SendAddress]

mail-cli/Tests/MailLibTests/
  RecipientResolverSpec.swift  UPDATE — AddressEntry → SendAddress; type references only

text-cli/Sources/TextLib/
  MessageSender.swift        UPDATE — delete SendResult; MessageSender returns [SendAddress]
  TargetResolver.swift       UPDATE — delete SendResult; migrate type references to SendAddress;
                                      interaction behavior unchanged (silent-first bugs deferred to 014)
  PhoneNormalizer.swift      DELETE — normalizePhone moves to ContactKit; formatPhone no longer needed

text-cli/Tests/TextLibTests/
  TargetResolverSpec.swift   UPDATE — SendResult → SendAddress; type references only
  PhoneNormalizerSpec.swift  DELETE — all tests move to ContactKit; file removed with source file
```

## Complexity Tracking

No constitution violations requiring justification.

---

## Note — Feature 014

The send flow redesign (interactive resolution, `mail prepare`, `text prepare`, group send, picker) was scoped out of 013 during planning. 013 is a pure type refactor with no behavior changes.

All deferred design work is captured in `specs/013-shared-send-address/mail-send-ux.md`. That document is the input to the 014 spec.

---

## Implementation Sequence

Ordered by dependency: types before consumers, shared layer before tool updates.

---

### Step 1 — ContactKit: SendAddress, AddressType, ResolvedAddress

File: `Sources/ContactKit/SendAddress.swift`

```swift
public enum AddressType: Equatable, Sendable {
    case email
    case phone
}

public struct SendAddress: Equatable, Sendable {
    public let name: String
    public let address: String
    public let type: AddressType

    public init(name: String, address: String, type: AddressType) {
        self.name = name
        self.address = address
        self.type = type
    }

    public var formatted: String {
        switch type {
        case .email:
            (name.isEmpty || name == address) ? address : "\(name) <\(address)>"
        case .phone:
            normalizePhone(address)
        }
    }
}

public struct ResolvedAddress: Equatable, Sendable {
    public let contact: Contact
    public let addresses: [SendAddress]
}
```

`formatted` for email produces bare address when `name` is empty or equals `address` (the synthetic contact case). For phone, delegates to `normalizePhone` — so `SendAddress.swift` must be compiled after `PhoneNormalization.swift`.

Display name hierarchy is applied by callers at construction time, using `contact.displayName` (already defined as `name.isEmpty ? company : name`). When `displayName` is also empty, callers use the field value.

---

### Step 2 — ContactKit: PhoneNormalization

File: `Sources/ContactKit/PhoneNormalization.swift`

Move `normalizePhone` and `phoneDigits` here as internal functions. `formatPhone` is deleted from TextLib (no longer needed).

```swift
/// Strip all non-digit characters from a string.
func phoneDigits(_ s: String) -> String {
    String(s.filter(\.isNumber))
}

/// Normalize a phone number to E.164. Returns input unchanged if not normalizable.
func normalizePhone(_ s: String) -> String {
    if s.contains("@") { return s }
    let digits = phoneDigits(s)
    if digits.count == 10 { return "+1" + digits }
    if digits.count == 11, digits.hasPrefix("1") { return "+" + digits }
    if s.hasPrefix("+") { return "+" + digits }
    return s
}
```

`normalizePhone` is identical to the current TextLib version, just relocated.

---

### Step 3 — ContactKit: update ContactMatching

File: `Sources/ContactKit/ContactMatching.swift`

Replace inline `filter(\.isNumber)` with `phoneDigits()`. Two occurrences:
- `let qDigits = String(q.filter(\.isNumber))` → `let qDigits = phoneDigits(q)`
- `String($0.value.filter(\.isNumber)).contains(qDigits)` → `phoneDigits($0.value).contains(qDigits)`

No behavioral change — same digit-stripping logic, now the single authoritative call.

---

### Step 4 — ContactKit: RecipientSearch

File: `Sources/ContactKit/RecipientSearch.swift`

One public function. Searches contacts and groups; when nothing matches, checks whether the input is a valid direct address and returns a synthetic contact if so. Callers receive `[Contact]` and do not need to know whether any contact is synthetic.

```swift
import Foundation

/// Search contacts and groups for a query string.
/// When no contact or group matches, checks whether the input is a valid email or phone
/// number and — if so — returns a synthetic contact constructed from it.
/// Returns [] only when nothing matches and the input is not a recognizable address.
/// Throws only on store errors (permission denied, fetch failure).
public func searchContacts(query: String, store: any ContactStore) async throws -> [Contact] {
    let q = query.trimmingCharacters(in: .whitespaces)
    let allContacts = try await store.contacts()
    let allGroups = try await store.fetchGroups()

    var result: [Contact] = matchContacts(q, in: allContacts)

    // Group expansion (parallel)
    let matchingGroups = allGroups.filter { $0.name.caseInsensitiveCompare(q) == .orderedSame }
    if !matchingGroups.isEmpty {
        let members = try await withThrowingTaskGroup(of: [Contact].self) { group in
            for contactGroup in matchingGroups {
                group.addTask { try await store.fetchContacts(in: contactGroup) }
            }
            var all: [Contact] = []
            for try await batch in group { all += batch }
            return all
        }
        var seen = Set(result.map(\.identifier))
        for c in members where seen.insert(c.identifier).inserted {
            result.append(c)
        }
    }

    if !result.isEmpty { return result }

    // Input is not a contact or group — check if it's a valid direct address
    if let type = addressType(of: q) {
        return [syntheticContact(from: q, type: type)]
    }

    return []
}

// MARK: - Internal helpers

private func addressType(of input: String) -> AddressType? {
    if isValidEmail(input) { return .email }
    if isValidPhone(input) { return .phone }
    return nil
}

private func isValidEmail(_ s: String) -> Bool {
    guard !s.contains(" ") else { return false }
    let parts = s.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
    return parts.count == 2 && !parts[0].isEmpty && !parts[1].isEmpty
}

private func isValidPhone(_ s: String) -> Bool {
    let count = phoneDigits(s).count
    return count >= 10 && count <= 15
}

private func syntheticContact(from address: String, type: AddressType) -> Contact {
    let field = ContactField(
        label: type == .email ? ContactField.defaultEmailLabel : ContactField.defaultPhoneLabel,
        value: address
    )
    return Contact(
        identifier: address,
        name: "",
        emails: type == .email ? [field] : [],
        phones: type == .phone ? [field] : [],
        company: ""
    )
}
```

---

### Step 5 — ContactKit: AddressRetrieval

File: `Sources/ContactKit/AddressRetrieval.swift`

```swift
/// Batch address retrieval. One entry per input contact.
/// contacts with no fields of the requested type have an empty addresses list — never dropped.
public func resolveAddresses(for contacts: [Contact], type: AddressType) -> [ResolvedAddress] {
    contacts.map { contact in
        let fields = type == .email ? contact.emails : contact.phones
        let resolved = fields.map { field -> SendAddress in
            let n = contact.displayName
            return SendAddress(name: n.isEmpty ? field.value : n,
                               address: field.value,
                               type: type)
        }
        return ResolvedAddress(contact: contact, addresses: resolved)
    }
}
```

Pure, synchronous. `contact.displayName` covers name → company fallback. When empty (synthetic contact), `field.value` becomes the display name.

---

### Step 6 — ContactKit tests

Four new spec files in `Tests/ContactKitTests/`. All class names prefixed `ContactKit` to avoid ObjC runtime collisions.

**`ContactKitSendAddressSpec.swift`** covers:
- Email `.formatted` with name → `"Name <email>"`
- Email `.formatted` with no name → bare address
- Email `.formatted` when name equals address (synthetic contact) → bare address
- Phone `.formatted` with 10-digit number → E.164 `+1XXXXXXXXXX`
- Phone `.formatted` with formatted number `"(415) 555-0100"` → `+14155550100`

**`ContactKitPhoneNormalizationSpec.swift`** — migrate all `normalizePhone` tests from `TextLibTests/PhoneNormalizerSpec.swift` with updated class name.

**`ContactKitRecipientSearchSpec.swift`** covers:
- Name match returns contact
- Email field match returns contact
- Phone field match (with formatting difference) returns contact
- Group name match returns member contacts
- Group + individual match returns flat union, deduplicated
- Direct email input with no contact match returns synthetic contact with `.email` type
- Direct phone input with no contact match returns synthetic contact with `.phone` type
- Input that matches nothing and is not a valid address returns `[]`
- Synthetic contact: identifier is the input string, name and company are both empty
- Multiple contacts with same name all returned (no reduction)

**`ContactKitAddressRetrievalSpec.swift`** covers:
- Contact with 3 emails → 3 resolved addresses returned
- Contact with 0 emails (email type requested) → empty addresses list, contact preserved
- Contact with 0 emails and contact with 1 email → 2 entries, one empty
- 100 contacts → 100 entries in output
- Display name hierarchy: name present → `name`; name empty, company present → company; both empty → field value
- Phone type: `.formatted` produces E.164 output
- Email type: `.formatted` produces RFC 5322 output

---

### Step 7 — TextLib: PhoneNormalizer

Delete `text-cli/Sources/TextLib/PhoneNormalizer.swift` entirely. `normalizePhone` is now internal to ContactKit. `formatPhone` is no longer needed — the ambiguous error shows raw stored values from the contact, and `SendAddress.formatted` handles E.164 for the actual send.

Delete `text-cli/Tests/TextLibTests/PhoneNormalizerSpec.swift`. All `normalizePhone` tests move to `ContactKitPhoneNormalizationSpec.swift`; `formatPhone` has no remaining test coverage to migrate.

---

### Step 8 — TextLib: MessageSender + TargetResolver

**`text-cli/Sources/TextLib/MessageSender.swift`** — delete `SendResult` struct. Update `MessageSender` protocol return type to `[SendAddress]` (imported from ContactKit).

**`text-cli/Sources/TextLib/TargetResolver.swift`** — delete `requiresContactLookup`. Update `resolveTarget` to use `searchContacts` and `resolveAddresses` from ContactKit, returning `[SendAddress]`. Interaction behavior unchanged — silent-first bugs deferred to Feature 014.

**`TextLibTests/TargetResolverSpec.swift`** — update type references `SendResult` → `SendAddress`. No new cases.

**`TextLibTests/PhoneNormalizerSpec.swift`** — delete. All `normalizePhone` tests move to `ContactKitPhoneNormalizationSpec.swift`. No `formatPhone` tests to preserve.

---

### Step 9 — MailLib: MailClient

File: `mail-cli/Sources/MailLib/MailClient.swift`

Update `OutboundEmail`:
```swift
public struct OutboundEmail: Equatable {
    public let from: MailIdentity
    public let to: [SendAddress]
    public let cc: [SendAddress]
    ...
}
```

`AddressEntry` is removed from the field types. `SendAddress` is imported from ContactKit (already a MailLib dependency).

---

### Step 10 — MailLib: RecipientResolver

**`mail-cli/Sources/MailLib/RecipientResolver.swift`** — delete `AddressEntry`, `requiresContactLookup`, `resolveRecipients`. Update `buildRecipients` to use `searchContacts` and `resolveAddresses` from ContactKit, returning `(to: [SendAddress], cc: [SendAddress])`. Interaction behavior unchanged — silent-first bugs deferred to Feature 014.

**`MailLibTests/RecipientResolverSpec.swift`** — update type references `AddressEntry` → `SendAddress`. No new cases.

---

### Step 11 — Build and test

```bash
swift build 2>&1 | head -60
swift test 2>&1 | tail -40
```

All tests must pass. No new warnings. Zero failures.
