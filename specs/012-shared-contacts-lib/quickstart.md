# Quickstart: Using the Shared Contact Library

## For a CLI that needs to look up contacts

```swift
// In your main.swift or async command handler:
import GetClearKit
import ContactKit

// 1. Request permission (tool already does this)
// 2. Load contacts from the shared backend
let store = AppleContactStore()
let allContacts = (try? await store.contacts()) ?? []

// 3. Match by name, email, or phone
let matches = matchContacts("alice", in: allContacts)
switch matches.count {
case 0: fail("No contact found matching 'alice'")
case 1: // use matches[0]
default: fail("Multiple contacts match 'alice'")
}
```

## SpyContactStore for tests

```swift
import GetClearKit

struct SpyContactStore: ContactStore {
    let result: [Contact]
    func contacts() async throws -> [Contact] { result }
}

// In Quick/Nimble spec:
let alice = Contact(name: "Alice Smith",
                   emails: [("work", "alice@example.com")],
                   phones: [("mobile", "+15551234567")],
                   company: "")
let spy = SpyContactStore(result: [alice])
let matches = matchContacts("alice", in: try await spy.contacts())
```

## Adding a new backend

1. Create a new type conforming to `ContactStore` in a new framework-boundary target
2. Implement `func contacts() async throws -> [Contact]`
3. Return `Contact` values with all fields as plain strings — no platform types
4. Wire the new store into the CLIs that should use it (via a config check in main.swift)

No changes to GetClearKit, ContactsLib, MailLib, TextLib, or any CLI handler.

## Package.swift minimum additions for a new tool

```swift
.target(
    name: "MyNewLib",
    dependencies: ["GetClearKit"],  // Contact type + matchContacts
    ...
),
.executableTarget(
    name: "mynew-bin",
    dependencies: ["MyNewLib", "GetClearKit", "ContactKit"],  // ContactKit for AppleContactStore
    ...
),
```
