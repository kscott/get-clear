# Contract: ContactStore

**Target**: `GetClearKit`  
**Type**: Protocol

```swift
public protocol ContactStore: Sendable {
    func contacts() async throws -> [Contact]
}
```

## Behavior contract

| Condition | Return |
|-----------|--------|
| Backend has contacts | `[Contact]` with all records, unfiltered |
| Backend has no contacts | `[]` |
| Access denied (at init/permission time) | caller prevents calling; return `[]` |
| Backend I/O error | throws |

## Implementors

| Type | Target | Description |
|------|--------|-------------|
| `AppleContactStore` | `ContactKit` | Production; reads from `CNContactStore` |
| `SpyContactStore` | test targets | Test double; holds pre-loaded `[Contact]` |

## SpyContactStore pattern

```swift
struct SpyContactStore: ContactStore {
    let result: [Contact]
    func contacts() async throws -> [Contact] { result }
}
```

Use in tests anywhere a `ContactStore` is required. No framework permissions needed.

## Caller contract

- Callers request Contacts permission before constructing `AppleContactStore` and calling `contacts()`
- Callers pass the result to `matchContacts(_:in:)` for filtering
- Callers are responsible for single/multiple/empty result handling — the library does not pick
