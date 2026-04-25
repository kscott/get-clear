# Contract: Contact

**Target**: `GetClearKit`  
**Type**: Struct

```swift
public struct Contact: Sendable {
    public let name: String
    public let emails: [(label: String, value: String)]
    public let phones: [(label: String, value: String)]
    public let company: String
    public var primaryEmail: String
    public var primaryPhone: String
}
```

## Field contract

| Field | Type | Empty means |
|-------|------|-------------|
| `name` | `String` | Organization-only record (use `company` for display) |
| `emails` | `[(label, value)]` | Contact has no email addresses |
| `phones` | `[(label, value)]` | Contact has no phone numbers |
| `company` | `String` | No organization name |
| `primaryEmail` | `String` (computed) | Contact has no email (`""`) |
| `primaryPhone` | `String` (computed) | Contact has no phone (`""`) |

## Invariants

- All string values are plain Swift strings — no platform types
- `label` may be empty string — callers must tolerate it
- `name` and `company` cannot both be empty in a well-formed record (but the type does not enforce this)
- No validation beyond what the backend provides

## What Contact does NOT expose

- `addressField` ("Name <email>" formatting) — mail-specific, belongs in MailLib
- Physical addresses — out of scope
- Photo, birthday, or any extended CNContact fields — out of scope

## Tool-specific usage patterns

**contacts-cli** — uses all fields for display via `cardLines(for: Contact)` in ContactsLib  
**mail-cli** — uses `primaryEmail` and all `emails` for recipient resolution  
**text-cli** — uses `primaryPhone` and all `phones` for send target resolution  
