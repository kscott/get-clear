# ContactKit

Pure shared contact types and matching logic. No framework imports. Every tool and Lib target that works with contacts depends on this target.

For the Apple Contacts backend and the factory that constructs it, see `Sources/AppleContactKit/` and `Sources/ContactStoreFactory/`.

---

## Types

### Contact

A record representing a person, business, or organization.

```swift
public struct Contact: Equatable, Sendable {
    public let name: String
    public let emails: [ContactField]
    public let phones: [ContactField]
    public let company: String
}
```

`name` and `company` may both be empty on a record that has only email or phone data. The tool decides how to handle display.

### ContactField

A labeled value — one email address or phone number.

```swift
public struct ContactField: Equatable, Hashable, Sendable {
    public let label: String   // e.g. "work", "mobile" — may be empty
    public let value: String   // plain string; no platform types
}
```

### ContactStore

Protocol for any contact backend.

```swift
public protocol ContactStore: Sendable {
    func contacts() async throws -> [Contact]
}
```

The backend returns all contacts unfiltered. Filtering and matching is the caller's responsibility via `matchContacts`.

---

## matchContacts

```swift
public func matchContacts(_ query: String, in contacts: [Contact]) -> [Contact]
```

Searches name, email, company, and phone. Returns results ranked by match quality. Empty query returns an empty list — callers that want all contacts call `store.contacts()` directly.

**Rank order** (lower = better match):

| Score | Condition |
|---|---|
| 0 | Exact name match |
| 1 | Name starts with query |
| 2 | Name contains query |
| 3 | Any email contains query |
| 4 | Exact company match |
| 5 | Company contains query |
| 6 | Phone digits contain query digits |

Matching is case-insensitive. Phone matching strips non-digit characters from both query and stored value before comparing.

---

## Testing

Define `SpyContactStore` locally in your test target — it does not need to be shared:

```swift
import ContactKit

struct SpyContactStore: ContactStore {
    let result: [Contact]
    func contacts() async throws -> [Contact] { result }
}
```

Use it anywhere a `ContactStore` is required. No permission prompts, no framework dependency.

---

## Package.swift

Lib targets that work with contacts depend on ContactKit only:

```swift
.target(
    name: "MyToolLib",
    dependencies: ["ContactKit"],
    ...
)
```

CLI binaries that need a live store depend on `ContactStoreFactory`:

```swift
.executableTarget(
    name: "mytool-bin",
    dependencies: ["MyToolLib", "ContactStoreFactory"],
    ...
)
```

Add `GetClearKit` to either target only if you need suite infrastructure (fail, arg parsing, ANSI output, etc.) — it is not required by ContactKit itself.
