# Plan: contacts-cli three-tier migration (#141)

Reference implementation: reminders-cli (#147).

---

## Goal

Apply the three-tier pattern to contacts-cli:

- **ContactKit** — protocol + pure value types. No framework imports.
- **AppleContactKit** — `AppleContactStore`: Contacts.framework boundary only.
- **ContactsLib** — handlers, formatting, parsing. No framework imports.
- **ContactsCLI** — `main.swift` dispatch only. No logic.

---

## Principles carried into this plan

- Protocol vocabulary matches reminders: `update`, `rename`, `delete` (not `change`, `remove`).
- Labels are not exposed through the CLI. They are an implementation detail assigned at the
  `AppleContactStore` boundary. `ContactField` stays in ContactKit for future use and for
  text-cli's phone resolution, but is never surfaced through add or change commands.
- Default labels are defined as named constants on `ContactField`, not hardcoded in the store:
  - email → `"work"`
  - phone → `"mobile"`
- All mutable fields (email, phone, company) use `ValueChange<String>` in `ContactChanges`.
  `ValueChange<T>` lives in `GetClearKit` and is the suite-wide standard change type. One type,
  no drift risk. Company is single-value in Apple Contacts — the parser constrains it to
  `.replaced` and `.cleared` only; the Apple boundary reads/writes only the first value.
  Email and phone support the full range: add, remove, replace (from → to), clear.
- `ContactDraft` is the creation input type. Fields are plain strings. The store assigns labels
  when converting to framework types.
- Confirmation output is computed by the formatter from the change structs — not pre-built and
  stored inside `ContactChanges`.
- text-cli is unaffected. `contacts()` stays as a default protocol extension calling
  `fetchContacts(in: nil)`. No changes to text-cli source.

---

## Open questions (resolve before implementing)

- [x] `ContactGroup` carries both `identifier: String` and `name: String`. Identifier included
      now — no real cost to carry it unused, likely needed for Google backend.
- [ ] Company: does the UI expose it in `show`? Can it be set in `add`? Can it be changed
      via `change`? (Current assumption: yes to all three.)
- [ ] `ContactChanges` — parser syntax for company: `contacts change Alice company Acme Corp`
      to set (`.replaced`); `company none` to clear. Confirm before implementing parser.

---

## ContactKit changes — `Sources/ContactKit/`

### Contact.swift

Add `identifier: String` as the first field.

```swift
public struct Contact: Equatable, Sendable {
    public let identifier: String
    public let name: String
    public let emails: [ContactField]
    public let phones: [ContactField]
    public let company: String
}
```

### ContactField.swift (or Contact.swift)

Add default label constants:

```swift
public extension ContactField {
    static let defaultEmailLabel = "work"
    static let defaultPhoneLabel = "mobile"
}
```

### ContactGroup.swift (new)

```swift
public struct ContactGroup: Equatable, Sendable {
    public let identifier: String
    public let name: String
    public init(identifier: String, name: String) {
        self.identifier = identifier; self.name = name
    }
}
```

### ContactDraft.swift (new)

Creation input type. Plain strings — no labels, no identifier.

```swift
public struct ContactDraft: Equatable, Sendable {
    public let name: String
    public let emails: [String]
    public let phones: [String]
    public let company: String?
    public init(name: String, emails: [String] = [], phones: [String] = [], company: String? = nil) {
        self.name = name; self.emails = emails; self.phones = phones; self.company = company
    }
}
```

### ContactChanges.swift (new — replaces ChangeCommand.swift in ContactsLib)

One change type for all fields. No shared-structure drift risk.

`ValueChange<T>` is defined in **GetClearKit** and is the suite-wide standard change type.
`ContactChanges` is defined in **ContactKit** (which gains a GetClearKit dependency).

```swift
// GetClearKit/ValueChange.swift
public enum ValueChange<T> {
    case unchanged
    case cleared
    case added(T)
    case removed(T)
    case replaced(from: T, to: T)
}

// ContactKit/ContactChanges.swift
public struct ContactChanges: Equatable {
    public let email: ValueChange<String>
    public let phone: ValueChange<String>
    public let company: ValueChange<String>
}
```

Company uses the same type as email and phone. The parser never produces `.added` or `.removed`
for company — that constraint lives in `parseContactChanges`, not in the type. For single-value
fields, the handler fetches the current contact first to supply the `from:` side of `.replaced`.
The Apple boundary reads and writes only the first company value, mapping to `CNContact.organizationName`.

`parseContactChanges` moves from ContactsLib/ChangeCommand.swift to
ContactsLib/ContactChangeParsing.swift. It imports ContactKit and produces `ContactChanges`.
No `descriptions` field — confirmation text is derived by the formatter from the struct.

### ContactStore.swift

Replace the current single-method protocol with the full suite. Keep `contacts()` as a default
extension for text-cli backward compatibility.

```swift
public enum ContactStoreError: Error {
    case notFound(String)
    case ambiguous([Contact])
    case groupNotFound(String)
}

public protocol ContactStore: Sendable {
    func fetchGroups() async throws -> [ContactGroup]
    func fetchContacts(in group: ContactGroup?) async throws -> [Contact]
    func add(_ draft: ContactDraft) async throws -> Contact
    func add(identifier: String, to group: ContactGroup) async throws
    func remove(identifier: String, from group: ContactGroup) async throws
    func update(identifier: String, changes: ContactChanges) async throws
    func rename(identifier: String, to newName: String) async throws
    func delete(identifier: String) async throws
}

public extension ContactStore {
    func contacts() async throws -> [Contact] { try await fetchContacts(in: nil) }

    func resolve(query: String) async throws -> Contact {
        let matches = matchContacts(query, in: try await fetchContacts(in: nil))
        switch matches.count {
        case 0: throw ContactStoreError.notFound(query)
        case 1: return matches[0]
        default: throw ContactStoreError.ambiguous(matches)
        }
    }

    func resolveGroup(named name: String) async throws -> ContactGroup {
        let groups = try await fetchGroups()
        guard let match = groups.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else {
            throw ContactStoreError.groupNotFound(name)
        }
        return match
    }
}
```

---

## AppleContactKit changes — `Sources/AppleContactKit/`

Full rewrite of `AppleContactStore.swift` to implement the expanded protocol.

Key behaviors:
- `fetchContacts(in group:)` — nil fetches all; non-nil resolves the group name to a `CNGroup`
  and uses `CNContact.predicateForContactsInGroup`.
- `add(_ draft:)` — constructs `CNMutableContact`, assigns default labels for each email/phone,
  saves, returns `toContact(savedContact)`.
- `update(identifier:changes:)` — contains the CoreData 134092 multi-container retry logic
  (moved here from the old `ChangeHandler.swift`). This is an Apple-specific concern.
- `toContact(_ c: CNContact)` — updated to populate `identifier: c.identifier`.

---

## ContactsLib changes — `contacts-cli/Sources/ContactsLib/`

### Files removed
- `Matching.swift` — `ContactRecord` and duplicate `matchContacts` deleted. `cleanLabel` already
  in AppleContactKit. `exportAddresses` moves to ContactFormatter.
- `ChangeCommand.swift` — `ContactChanges`/`FieldChange` move to ContactKit.
  `parseContactChanges` becomes `ContactChangeParsing.swift`.

### Files updated
- `ContactFormatter.swift` — operates on `Contact` (not `ContactRecord`). Adds `exportAddresses`.

### Files added (handlers, one per command)
Each handler is `async throws -> String`. Receives `any ContactStore`.

- `ContactHandlerError.swift`
- `ContactChangeParsing.swift` (replaces ChangeCommand.swift)
- `UsageText.swift`
- `OpenHandler.swift`
- `WhatHandler.swift`
- `ListHandler.swift` — covers `lists`, `list <group>`, `export <group>`
- `FindHandler.swift`
- `ShowHandler.swift`
- `AddHandler.swift` — covers `add <draft>` and `add <name> to <group>`
- `ChangeHandler.swift`
- `RenameHandler.swift`
- `RemoveHandler.swift` — covers `remove <contact>` and `remove <contact> from <group>`

---

## ContactsCLI changes — `contacts-cli/Sources/ContactsCLI/`

### Files removed
All current command files: `ContactConversion.swift`, `AddCommand.swift`, `FindCommand.swift`,
`ListCommand.swift`, `ShowCommand.swift`, `ChangeHandler.swift`, `RenameCommand.swift`,
`RemoveCommand.swift`, `OpenCommand.swift`, `WhatCommand.swift`.

### Files updated
- `main.swift` — async dispatch only, no semaphore, `await makeContactStore()`.
- `Usage.swift` — calls `usageText()` from ContactsLib.

### Files unchanged
- `Version.swift`

---

## Package.swift changes

`ContactKit` gains a `GetClearKit` dependency (for `ValueChange<T>`).

```swift
.target(
    name: "ContactKit",
    dependencies: ["GetClearKit"],
    path: "Sources/ContactKit"
),
.target(
    name: "ContactsLib",
    dependencies: ["ContactKit", "GetClearKit"],
    path: "contacts-cli/Sources/ContactsLib"
),
.executableTarget(
    name: "contacts-bin",
    dependencies: ["ContactsLib", "ContactStoreFactory", "GetClearKit"],
    path: "contacts-cli/Sources/ContactsCLI",
    linkerSettings: [.linkedFramework("AppKit")]
),
.testTarget(
    name: "ContactKitTests",
    dependencies: [
        "ContactKit", "GetClearKit",
        .product(name: "Quick", package: "Quick"),
        .product(name: "Nimble", package: "Nimble"),
    ],
    path: "Tests/ContactKitTests"
),
.testTarget(
    name: "ContactsLibTests",
    dependencies: [
        "ContactsLib", "ContactKit", "GetClearKit",
        .product(name: "Quick", package: "Quick"),
        .product(name: "Nimble", package: "Nimble"),
    ],
    path: "contacts-cli/Tests/ContactsLibTests"
),
```

---

## Tests

### GetClearKitTests (add)
- New: `ValueChangeSpec.swift` — `ValueChange<T>` construction and case coverage.

### ContactKitTests (update existing)
- `ContactStoreSpec.swift` — add `identifier: ""` to all `Contact` constructions.
- `SpyContactStoreSpec.swift` — update for expanded protocol.
- New: `ContactChangesSpec.swift` — `ValueChange<String>` construction for all three fields.
- New: `ContactDraftSpec.swift` — draft construction.

### ContactsLibTests (replace existing)
- `ContactFormatterSpec.swift` — update to use `Contact`.
- `ContactChangeParsing.swift` — replaces `ChangeCommandSpec.swift`.
- Handler specs — one per handler, using a `SpyContactStore` defined locally.
- Remove `MatchingSpec.swift` (ContactRecord gone).

### AppleContactKitTests (update)
- `ToContactSpec.swift` — add identifier field expectations.

---

## Commit order

1. GetClearKit: `ValueChange<T>` + `ValueChangeSpec.swift` in GetClearKitTests
2. ContactKit + Package.swift: expand Contact, add ContactGroup, ContactDraft, ContactChanges,
   full protocol — Package.swift update (ContactKit gains GetClearKit dep) in the same commit
   so the tree compiles at every step
3. AppleContactKit: full AppleContactStore rewrite
4. ContactsLib: handlers, formatter, parsing — all tests included
5. ContactsCLI: main.swift rewrite, old files deleted
6. Tests: ContactKitTests + AppleContactKitTests updates
