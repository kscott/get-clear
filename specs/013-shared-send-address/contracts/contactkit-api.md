# ContactKit Public API — Feature 013 Additions

These are the new and changed public symbols exported by `ContactKit` after this feature lands. Existing symbols (`Contact`, `ContactField`, `ContactGroup`, `ContactStore`, `matchContacts`, etc.) are unchanged.

---

## New types

```swift
public enum AddressType: Equatable, Sendable {
    case email
    case phone
}

public struct SendAddress: Equatable, Sendable {
    public let name: String
    public let address: String
    public let type: AddressType
    public init(name: String, address: String, type: AddressType)
    public var formatted: String  // RFC 5322 for email; E.164 for phone
}

public struct ResolvedAddress: Equatable, Sendable {
    public let contact: Contact
    public let addresses: [SendAddress]
}
```

---

## New functions

```swift
/// Search contacts and groups for a query. When nothing matches, checks whether
/// the input is a valid email or phone number and returns a synthetic contact if so.
/// Callers receive [Contact] and do not need to know whether any contact is synthetic.
///
/// - query: The raw recipient string as typed. Whitespace trimmed internally.
/// - store: The contact backend. Fetches all contacts, all groups, and — when a group
///   name matches the query — that group's member contacts.
///
/// Returns [] only when nothing matches and the input is not a recognizable address.
/// Throws only on store errors (e.g. permission denied, fetch failure).
public func searchContacts(
    query: String,
    store: any ContactStore
) async throws -> [Contact]

/// Batch address retrieval. Returns one entry per input contact, each paired with
/// that contact's fields of the requested type as SendAddress values.
/// A contact with no fields of the requested type produces an empty addresses list —
/// it is never dropped from the output.
///
/// - contacts: The contacts to retrieve addresses for, in order.
/// - type: The address type to retrieve. Must be specified explicitly by the caller;
///   the shared layer never infers it.
public func resolveAddresses(
    for contacts: [Contact],
    type: AddressType
) -> [ResolvedAddress]
```

---

## Behavioral contracts

- `searchContacts` never throws for "no match" — throws only on store errors. Empty array means no contact or group matched AND the input is not a recognizable email or phone number.
- `resolveAddresses` is pure and synchronous. No store access. Output order matches input order.
- `SendAddress.formatted` for email: bare address when `name.isEmpty || name == address`; `"Name <address>"` otherwise.
- `SendAddress.formatted` for phone: always E.164, regardless of how the value was stored.

---

## What callers must NOT do

- Callers must not assemble the RFC 5322 or E.164 string themselves. Use `formatted`.
- Callers must not pre-normalize phone values before constructing `SendAddress`. Raw values go in; canonical form comes out via `formatted`.
- Callers must not infer `AddressType` from context. It must be passed explicitly.
