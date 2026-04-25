# Data Model: Shared Contact Resolution Library

## Entities

### Contact

The unified contact record. Replaces `ContactRecord` (ContactsLib), `MessageContact` (TextLib), and `MailContact` (MailLib).

```swift
public struct Contact: Sendable {
    public let name: String                              // "Alice Smith" or "" for org-only
    public let emails: [(label: String, value: String)] // [("work", "alice@example.com")]
    public let phones: [(label: String, value: String)] // [("mobile", "+15551234567")]
    public let company: String                           // "" when not set

    public var primaryEmail: String { emails.first?.value ?? "" }
    public var primaryPhone: String { phones.first?.value ?? "" }
}
```

**Constraints:**
- All fields are plain Swift strings — no platform types (CNPhoneNumber, NSString, etc.)
- `name` may be empty when the record represents an organization (`company` is non-empty)
- `emails` and `phones` may each be empty
- `label` may be empty — callers must tolerate ""
- No validation — Contact is a value type reflecting what came from the backend

**What Contact does NOT include:**
- `addressField` — "Name <email>" formatting is mail-specific, not on the type
- Physical addresses — out of scope per spec
- Photo, birthday, or any other CNContact field — out of scope

---

### ContactStore

The backend abstraction. One active backend at a time (Apple or Google).

```swift
public protocol ContactStore: Sendable {
    func contacts() async throws -> [Contact]
}
```

**Contract:**
- Returns the full contact list for the active backend
- Results are unfiltered and unsorted — callers apply matchContacts for filtering
- Empty list is valid (no contacts, or access denied by caller before calling)
- Throws on backend errors (I/O, auth failures after initial permission grant)

**Implementations:**
- `AppleContactStore` — production implementation in ContactKit target
- `SpyContactStore` — test double in test targets; holds a pre-loaded `[Contact]` array

---

### matchContacts (free function, not a protocol requirement)

```swift
public func matchContacts(_ query: String, in contacts: [Contact]) -> [Contact]
```

**Matching logic** (score, ascending = better):
| Score | Condition |
|-------|-----------|
| 0 | `name == query` (exact, case-insensitive) |
| 1 | `name.hasPrefix(query)` |
| 2 | `name.contains(query)` |
| 3 | any email value contains query |
| 4 | `company == query` (exact) |
| 5 | `company.contains(query)` |
| 6 | any phone (digits only) contains query digits |
| nil | no match — excluded from results |

**Invariants:**
- Empty query returns all contacts (unchanged order)
- Non-empty query with no matches returns `[]`
- Matching is case-insensitive on name, email, company
- Phone matching strips all non-digit characters from both query and stored value

---

### AppleContactStore

```swift
public final class AppleContactStore: ContactStore {
    public init(store: CNContactStore = CNContactStore())
    public func contacts() async throws -> [Contact]
}

public func toContact(_ c: CNContact) -> Contact

internal func cleanLabel(_ raw: String) -> String
```

**Keys fetched**: `givenName`, `familyName`, `organizationName`, `emailAddresses`, `phoneNumbers`

**Conversion rules:**
- `name` = `[givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")`
- `company` = `organizationName`
- `emails` = `emailAddresses.map { (cleanLabel($0.label ?? ""), $0.value as String) }`
- `phones` = `phoneNumbers.map { (cleanLabel($0.label ?? ""), $0.value.stringValue) }`

**cleanLabel rules:**
- Strips `_$!<` prefix and `>!$_` suffix (Apple's CNLabel wrapping format)
- Lowercases the result
- Passes through plain strings unchanged (lowercases them)

---

## Type relationships

```
ContactStore (protocol, GetClearKit)
    └── AppleContactStore (class, ContactKit)
    └── SpyContactStore   (struct, test targets only)

Contact (struct, GetClearKit)
    ← produced by ContactStore.contacts()
    ← produced by toContact() (ContactKit)
    ← consumed by matchContacts()
    ← consumed by ContactsLib (display)
    ← consumed by MailLib (recipient resolution)
    ← consumed by TextLib (phone/send resolution)
```

---

## Migration map (old types → new)

| Old type | Old home | New type | New home |
|----------|----------|----------|----------|
| `ContactRecord` | ContactsLib | `Contact` | GetClearKit |
| `MessageContact` | TextLib | `Contact` | GetClearKit |
| `MailContact` | MailLib | `Contact` | GetClearKit |
| `matchContacts(_ query:in:[ContactRecord])` | ContactsLib | `matchContacts(_ query:in:[Contact])` | GetClearKit |
| `toRecord(_ c: CNContact)` | ContactsCLI | `toContact(_ c: CNContact)` | ContactKit |
| `loadMessageContacts(from:)` | TextCLI | `AppleContactStore.contacts()` | ContactKit |
| `loadContacts(from:)` | MailCLI | `AppleContactStore.contacts()` | ContactKit |
| `allContacts(store:)` | ContactsCLI | stays private in ContactConversion.swift | ContactsCLI |
