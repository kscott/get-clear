# ContactKit

Framework boundary for Apple Contacts. Provides the production `ContactStore` backend and the factory that requests permission and constructs it.

The shared `Contact` type, `ContactStore` protocol, and `matchContacts()` function live in **GetClearKit** — import that for all matching and display logic. Import **ContactKit** only for the production store.

---

## Wiring a tool

```swift
import GetClearKit
import ContactKit

// In your async command handler:
let store = await makeContactStore()          // requests permission; exits on denial
let contacts = try await store.contacts()     // load all contacts once
let matches = matchContacts(query, in: contacts)
```

The caller decides what to do with the results. Two common patterns:

**Display all matches** (e.g. `contacts find`):
```swift
if matches.isEmpty { fail("No contact found matching '\(query)'") }
for contact in matches { /* render */ }
```

**Resolve to exactly one** (e.g. mail To:, text send target):
```swift
switch matches.count {
case 0:  fail("No contact found matching '\(query)'")
case 1:  // use matches[0]
default: fail("'\(query)' matches \(matches.count) contacts")
}
```

`makeContactStore()` calls `fail()` if Contacts access is denied — same pattern as `makeReminderStore()` in reminders-cli. No error handling needed at the call site.

Load contacts once per command invocation, then call `matchContacts` as many times as needed against the same slice (e.g., To: and Cc: in a single mail send).

---

## Package.swift additions

```swift
.target(
    name: "MyToolLib",
    dependencies: ["GetClearKit"],   // Contact type + matchContacts; no framework import
    ...
),
.executableTarget(
    name: "mytool-bin",
    dependencies: ["MyToolLib", "GetClearKit", "ContactKit"],
    linkerSettings: [.linkedFramework("Contacts")]
),
```

`ContactKit` links the Contacts framework. `MyToolLib` must not import ContactKit — keep the framework boundary out of Lib targets.

---

## Testing

Define `SpyContactStore` locally in your test target — it does not need to be shared:

```swift
import GetClearKit

struct SpyContactStore: ContactStore {
    let result: [Contact]
    func contacts() async throws -> [Contact] { result }
}
```

Use it anywhere a `ContactStore` is required. No permission prompts, no framework dependency.

```swift
let spy = SpyContactStore(result: [
    Contact(name: "Alice Smith",
            emails: [ContactField(label: "work", value: "alice@example.com")],
            phones: [ContactField(label: "mobile", value: "+15551234567")],
            company: "Acme")
])
let contacts = try await spy.contacts()
let matches = matchContacts("alice", in: contacts)
```

---

## What lives where

| Symbol | Target | Import |
|---|---|---|
| `Contact`, `ContactField` | GetClearKit | `import GetClearKit` |
| `ContactStore` protocol | GetClearKit | `import GetClearKit` |
| `matchContacts()` | GetClearKit | `import GetClearKit` |
| `makeContactStore()` | ContactKit | `import ContactKit` |
