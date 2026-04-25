# Implementation Plan: Shared Contact Resolution Library

**Branch**: `012-shared-contacts-lib` | **Date**: 2026-04-25 | **Spec**: [spec.md](spec.md)  
**Input**: Feature specification from `/specs/012-shared-contacts-lib/spec.md`

## Summary

Three per-tool contact types (`ContactRecord` in ContactsLib, `MessageContact` in TextLib, `MailContact` in MailLib) are consolidated into a single `Contact` type in GetClearKit, alongside a `ContactStore` protocol and the shared `matchContacts` function. A new framework-boundary target `ContactKit` provides `AppleContactStore` — the concrete Apple Contacts backend. All three tools (contacts, mail, text) drop their per-tool loading and matching code and use the shared layer.

## Technical Context

**Language/Version**: Swift 5.9 (swift-tools-version: 5.9)  
**Primary Dependencies**: Quick + Nimble (testing); GetClearKit (shared suite library); Contacts framework (framework boundary only)  
**Storage**: N/A — read-only access to Apple CNContactStore; no writes from the shared layer  
**Testing**: Quick + Nimble via `swift test`; pure Contact/matchContacts tests need no permissions  
**Target Platform**: macOS 14+  
**Project Type**: Library targets within monorepo (GetClearKit extension + new ContactKit target)  
**Performance Goals**: N/A — contact loading is synchronous enumeration, same as today  
**Constraints**: GetClearKit must remain free of framework imports; ContactKit imports Contacts but contains no business logic  
**Scale/Scope**: 3 tools consume the shared layer; 4 files deleted; ~200 lines of duplication removed

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Rule | Status | Notes |
|------|--------|-------|
| GetClearKit first | ✓ PASS | Contact + ContactStore + matchContacts live in GetClearKit |
| No framework imports in Lib | ✓ PASS | ContactKit (framework boundary) imports Contacts; GetClearKit does not |
| No duplication | ✓ PASS | Three per-tool types become one; loading code consolidated in AppleContactStore |
| Add/remove ship together | ✓ N/A | Read-only library; no add/remove commands |
| Tests ship with code | ✓ PASS | GetClearKitTests gains two new spec files; ContactKitTests gains one |
| No flags | ✓ N/A | Library, no CLI interface |

## Project Structure

### Documentation (this feature)

```text
specs/012-shared-contacts-lib/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks — not created here)
```

### Source Code

New files are marked **NEW**. Deleted files are marked **DELETE**. All others are updates.

```text
Sources/GetClearKit/
  Contact.swift           NEW  — Contact struct + primaryEmail/primaryPhone
  ContactStore.swift      NEW  — ContactStore protocol + matchContacts() function

Sources/ContactKit/       NEW TARGET
  AppleContactStore.swift NEW  — ContactStore implementation using CNContactStore
                                 Exports public func toContact(_ c: CNContact) -> Contact
                                 Internal func cleanLabel(_ raw: String) -> String

Tests/GetClearKitTests/
  ContactSpec.swift       NEW  — Contact type and accessor tests
  ContactStoreSpec.swift  NEW  — matchContacts tests (migrated from MatchingSpec)

Tests/ContactKitTests/    NEW TARGET
  CleanLabelSpec.swift    NEW  — cleanLabel tests (migrated from MatchingSpec)

contacts-cli/Sources/ContactsLib/
  Matching.swift          UPDATE — remove ContactRecord, matchContacts, cleanLabel, addressField
                                   update exportAddresses to take [Contact] and inline formatting
  ContactFormatter.swift  UPDATE — ContactRecord → Contact

contacts-cli/Sources/ContactsCLI/
  ContactConversion.swift UPDATE — remove toRecord() (moved to ContactKit as toContact())
                                   remove allContacts() (stays private, uses keysToFetch from ContactKit)
                                   cnContact(named:in:) updated to use toContact() + matchContacts()

contacts-cli/Tests/ContactsLibTests/
  MatchingSpec.swift      UPDATE — remove ContactRecord describe block, matchContacts tests, cleanLabel tests
                                   keep exportAddresses tests; update Contact fixture construction
  ContactFormatterSpec.swift UPDATE — ContactRecord → Contact

text-cli/Sources/TextLib/
  PhoneNormalizer.swift   UPDATE — remove MessageContact; resolveSendTarget takes [Contact]
                                   contact.phones.first?.value, contact.emails.first?.value

text-cli/Sources/TextCLI/
  ContactsLoader.swift    DELETE — replaced by AppleContactStore
  main.swift              UPDATE — remove loadMessageContacts; use AppleContactStore.contacts()
  SendCommand.swift       UPDATE — [MessageContact] → [Contact]
  OpenCommand.swift       UPDATE — [MessageContact] → [Contact]

text-cli/Tests/TextLibTests/
  PhoneNormalizerSpec.swift UPDATE — MessageContact → Contact (labeled tuple syntax)

mail-cli/Sources/MailLib/
  RecipientResolver.swift UPDATE — remove MailContact; contacts param takes [Contact]
                                   inner fuzzy match delegates to matchContacts() from GetClearKit
                                   email value access: $0.emails.first?.value

mail-cli/Sources/MailLib/
  SendCommand.swift       UPDATE — contacts param: [MailContact] → [Contact]

mail-cli/Sources/MailCLI/
  SendCommand.swift       UPDATE — remove loadContacts(); use AppleContactStore.contacts()
                                   remove Contacts import (now in ContactKit)

mail-cli/Tests/MailLibTests/
  RecipientResolverSpec.swift UPDATE — MailContact → Contact (labeled tuples for emails/phones)

Package.swift             UPDATE — add ContactKit target; add GetClearKit dep to MailLib + TextLib;
                                   add ContactKit dep to contacts-bin, mail-bin, text-bin
                                   add ContactKitTests test target
```

## Complexity Tracking

No constitution violations requiring justification.

---

## Implementation Sequence

Ordered by dependency: types before consumers, shared layer before tool updates.

### Step 1 — GetClearKit: Contact type and ContactStore protocol

Files: `Sources/GetClearKit/Contact.swift`, `Sources/GetClearKit/ContactStore.swift`

**Contact.swift:**
```swift
public struct Contact: Sendable {
    public let name: String
    public let emails: [(label: String, value: String)]
    public let phones: [(label: String, value: String)]
    public let company: String
    public var primaryEmail: String { emails.first?.value ?? "" }
    public var primaryPhone: String { phones.first?.value ?? "" }
}
```

Note: `addressField` is NOT on Contact — it was mail-specific formatting. `exportAddresses` in ContactsLib inlines it.

**ContactStore.swift:**
```swift
public protocol ContactStore: Sendable {
    func contacts() async throws -> [Contact]
}

public func matchContacts(_ query: String, in contacts: [Contact]) -> [Contact]
```

`matchContacts` is a free function, not a protocol requirement. Protocol is load-only; matching is a separate pure operation.

The matching algorithm from `ContactsLib/Matching.swift` is the authoritative implementation (more complete than MailLib/TextLib versions — includes company and phone). Copy it verbatim, updating `ContactRecord` → `Contact` throughout.

### Step 2 — GetClearKitTests: Contact and matchContacts specs

Files: `Tests/GetClearKitTests/ContactSpec.swift`, `Tests/GetClearKitTests/ContactStoreSpec.swift`

**ContactSpec.swift** covers:
- `primaryEmail` returns first email value
- `primaryEmail` returns empty string when no emails
- `primaryPhone` returns first phone value
- `primaryPhone` returns empty string when no phones

**ContactStoreSpec.swift** — migrate all `matchContacts` tests from `MatchingSpec.swift`:
- Name matching (partial, case-insensitive, prefix, exact)
- Email matching (domain substring)
- Company matching (exact, partial)
- Phone matching (digit string, with dashes)
- Sort order (exact > prefix > substring)
- Edge cases (empty query returns all, unmatched returns empty)

### Step 3 — ContactKit: AppleContactStore

Files: `Sources/ContactKit/AppleContactStore.swift`; Package.swift update

```swift
import Foundation
import Contacts
import GetClearKit

internal func cleanLabel(_ raw: String) -> String { ... }

public func toContact(_ c: CNContact) -> Contact { ... }

public final class AppleContactStore: ContactStore {
    private let cnStore: CNContactStore
    public init(store: CNContactStore = CNContactStore()) { ... }
    public func contacts() async throws -> [Contact] { ... }
}
```

`toContact` is public — ContactsCLI needs it for its write-side bridge (finding CNContact from a Contact result). `cleanLabel` is internal — only used by `toContact`.

**Package.swift additions:**
```swift
.target(
    name: "ContactKit",
    dependencies: ["GetClearKit"],
    path: "Sources/ContactKit",
    linkerSettings: [.linkedFramework("Contacts")]
),
.testTarget(
    name: "ContactKitTests",
    dependencies: [
        "ContactKit",
        .product(name: "Quick", package: "Quick"),
        .product(name: "Nimble", package: "Nimble"),
    ],
    path: "Tests/ContactKitTests"
),
```

Add `GetClearKit` to MailLib and TextLib dependencies. Add `ContactKit` to contacts-bin, mail-bin, text-bin dependencies.

### Step 4 — ContactKitTests: CleanLabel spec

File: `Tests/ContactKitTests/CleanLabelSpec.swift`

Migrate cleanLabel tests from MatchingSpec (uses `@testable import ContactKit`):
- strips `_$!<...>!$_` CNLabel wrapping
- lowercases plain strings
- passes through empty string unchanged

### Step 5 — ContactsLib: update Matching.swift

Remove: `ContactRecord`, `matchContacts`, `cleanLabel`, `addressField`  
Update: `exportAddresses` takes `[Contact]`, inlines "Name <email>" formatting  
Import: `GetClearKit` (already imported via `import Foundation`... add `import GetClearKit`)

```swift
public func exportAddresses(_ contacts: [Contact]) -> String {
    contacts.filter { !$0.primaryEmail.isEmpty }
            .map    { "\($0.name) <\($0.primaryEmail)>" }
            .joined(separator: ", ")
}
```

### Step 6 — ContactsLib: update ContactFormatter.swift

One-line change: `ContactRecord` → `Contact` in the function signature. All field access is unchanged (labels and values have the same shape).

### Step 7 — ContactsCLI: update ContactConversion.swift

Remove: `toRecord()` (replaced by `toContact()` from ContactKit)  
Keep: `allContacts()`, `cnContact()`, `group()`, `applyChanges()`  
Update: `cnContact(named:in:)` uses `toContact()` + `matchContacts()` from GetClearKit

```swift
import ContactKit   // for toContact()
import GetClearKit  // for matchContacts(), Contact

func cnContact(named query: String, in contacts: [CNContact]) -> CNContact? {
    let records = contacts.map(toContact)
    guard let first = matchContacts(query, in: records).first else { return nil }
    return zip(contacts, records).first { $1.name == first.name }?.0
}
```

### Step 8 — ContactsCLI: update all handlers

ListCommand.swift: `toRecord` → `toContact` (2 calls)  
Other handlers using `toRecord` or `ContactRecord`: update to `toContact` / `Contact`

### Step 9 — ContactsLibTests: update both spec files

**MatchingSpec.swift:**
- Remove `describe("matchContacts")` block (moved to GetClearKitTests)
- Remove `describe("ContactRecord")` block (moved to GetClearKitTests)
- Remove `describe("cleanLabel")` block (moved to ContactKitTests)
- Keep `describe("exportAddresses")` — update fixture construction: `ContactRecord(...)` → `Contact(...)`
- Remove import of old ContactRecord-specific test helpers

**ContactFormatterSpec.swift:**
- `makeContact()` return type: `ContactRecord` → `Contact`
- `ContactRecord(...)` → `Contact(...)` throughout

### Step 10 — TextLib: update PhoneNormalizer.swift

Remove `MessageContact` struct.  
Update `resolveSendTarget`:
- Parameter: `contacts: [Contact]` (import GetClearKit)
- `contact.phones.first` → `contact.phones.first?.value`
- `contact.emails.first` → `contact.emails.first?.value`

### Step 11 — TextCLI: update main.swift, delete ContactsLoader.swift

Delete `ContactsLoader.swift`.

In `main.swift`:
- Remove `import Contacts` (now inside ContactKit)
- Remove `loadMessageContacts(from: store)` call
- Use `AppleContactStore.contacts()` in async context

The contacts permission request moves into the async task body (same as today, but the store is now `AppleContactStore`):
```swift
import ContactKit
let contactStore = AppleContactStore()
let contacts = (try? await contactStore.contacts()) ?? []
```

### Step 12 — TextCLI: update SendCommand.swift and OpenCommand.swift

`[MessageContact]` → `[Contact]` in function signatures. Internal logic unchanged (resolveSendTarget handles the rest).

### Step 13 — TextLibTests: update PhoneNormalizerSpec.swift

`MessageContact(name:phones:emails:)` → `Contact(name:emails:phones:company:)`  
Note: Contact requires labeled tuple syntax — `emails: [("", "alice@example.com")]` instead of `["alice@example.com"]`  
Note: Contact has `company:` parameter (pass `""`)

### Step 14 — MailLib: update RecipientResolver.swift

Remove `MailContact` struct.  
Update `resolveRecipients`:
- Parameter: `contacts: [Contact]` (import GetClearKit)
- Step 3 (fuzzy match) delegates to `matchContacts()` instead of local score function
- Email value access: `$0.value` on labeled tuple
- Primary email: `matched.first?.primaryEmail` instead of `matched.first?.emails.first`

```swift
import GetClearKit

public func resolveRecipients(
    _ input: String,
    groups:   [String: [AddressEntry]],
    contacts: [Contact]
) -> [AddressEntry] {
    // ... group and raw email logic unchanged ...
    
    // Step 3: delegate to shared matchContacts
    let matched = matchContacts(ql, in: contacts)
    if let first = matched.first, let email = first.primaryEmail.isEmpty ? nil : first.primaryEmail {
        return [AddressEntry(name: first.name, email: email)]
    }
    return []
}
```

Email lookup in step 2 (raw email path):
```swift
let name = contacts.first(where: {
    $0.emails.contains(where: { $0.value.caseInsensitiveCompare(q) == .orderedSame })
})?.name ?? ""
```

### Step 15 — MailLib: update SendCommand.swift

`contacts: [MailContact]` → `contacts: [Contact]` in `runSend` signature and downstream call.

### Step 16 — MailCLI: update SendCommand.swift

Remove `loadContacts()` private function.  
Use `AppleContactStore`:
```swift
import ContactKit
let appleStore = AppleContactStore(store: contactStore)
let contacts = (try? await appleStore.contacts()) ?? []
```

Remove Contacts framework import from MailCLI/SendCommand.swift (groups loading still needs it — keep for group logic only).

Actually: `loadGroups()` still uses CNContactStore directly. Keep Contacts import in MailCLI/SendCommand.swift. Only `loadContacts()` is removed.

### Step 17 — MailLibTests: update RecipientResolverSpec.swift

`MailContact(name:emails:)` → `Contact(name:emails:phones:company:)`  
Labeled tuple syntax: `emails: [("", "alice@example.com"), ("", "alice@work.com")]`  
The `resolveRecipients` call now takes `[Contact]` instead of `[MailContact]`.

### Step 18 — Build and test

```bash
swift build 2>&1 | head -50
swift test 2>&1 | tail -30
```

All tests must pass. No new warnings.
