# Data Model: Shared Recipient Resolution Foundation

---

## New types (ContactKit)

### `AddressType`

```swift
public enum AddressType: Equatable, Sendable {
    case email
    case phone
}
```

A closed set. Exactly two values. Callers specify explicitly; the shared layer never infers it.

---

### `SendAddress`

```swift
public struct SendAddress: Equatable, Sendable {
    public let name: String     // resolved display name
    public let address: String  // raw address value from contact store
    public let type: AddressType

    public init(name: String, address: String, type: AddressType)

    /// Canonical sending string. RFC 5322 for email; E.164 for phone.
    public var formatted: String
}
```

**Display name resolution (applied by `resolveAddresses`):**

`name` is set to `contact.displayName`. When `displayName` is empty — no name and no company, which occurs for synthetic contacts and for real contacts that were stored without either — `resolveAddresses` falls back to the field value (the raw address string). Callers do not set `name` directly.

**`formatted` computed property:**

- Email: `"Name <address>"` when the contact has a real name; bare `address` when `name` is empty or equals `address` (the synthetic contact case).
- Phone: E.164 regardless of how the value was stored.

---

### `ResolvedAddress`

```swift
public struct ResolvedAddress: Equatable, Sendable {
    public let contact: Contact
    public let addresses: [SendAddress]
}
```

One entry per input contact. `addresses` is empty when the contact has no fields of the requested type — it is never nil or absent. The contact is preserved so callers can produce the FR-013 "contact found but no address of this type" error message using `contact.displayName`.

---

## Moved functions (TextLib → ContactKit, internal)

### `normalizePhone` and `phoneDigits`

```swift
// ContactKit/PhoneNormalization.swift  (internal — not public API)

func phoneDigits(_ s: String) -> String
func normalizePhone(_ s: String) -> String
```

`phoneDigits` is the single shared digit-stripping function used by `ContactMatching.swift`, direct address detection, and `SendAddress.formatted`. `normalizePhone` moves unchanged from `TextLib/PhoneNormalizer.swift` but is now implemented using `phoneDigits`.

Both are internal to ContactKit — no module consumer calls them directly. `SendAddress.formatted` is the public surface.

`formatPhone` (display formatting, e.g., "(555) 123-4567") is deleted from `TextLib` — the ambiguous error for multiple phones shows raw stored values; no caller needs display-formatted phone strings after this change.

---

## New functions (ContactKit)

### `searchContacts`

```swift
public func searchContacts(
    query: String,
    store: any ContactStore
) async throws -> [Contact]
```

Unified search pipeline. Fetches all contacts and groups from the store internally. Resolution order:

1. `matchContacts(query, in: allContacts)` — ranked by match quality.
2. Case-insensitive group name match. Each matching group expanded via `store.fetchContacts(in:)`, run in parallel with `withThrowingTaskGroup`.
3. Results from 1 and 2 merged and deduplicated by `identifier`.
4. If result is non-empty → return.
5. If input is a valid email or phone (direct address detection, internal) → return a synthetic contact constructed from it.
6. If neither → return `[]`.

Returns `[]` only when nothing matches and the input is not a recognizable address. Callers do not need to know whether a returned contact is synthetic.

---

### `resolveAddresses`

```swift
public func resolveAddresses(
    for contacts: [Contact],
    type: AddressType
) -> [ResolvedAddress]
```

Pure, synchronous. Maps each contact to its fields of the requested type. Empty `addresses` when a contact has no fields of that type — never drops the contact from the output. One entry per input contact. Order preserved.

---


