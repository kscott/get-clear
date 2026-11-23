# Data Model: Get Clear App — Own Privacy Identity and Self-Update

**Feature**: 018-app-bundle-identity | **Date**: 2026-11-23

Everything in this file is a pure value type: `Codable`, `Equatable`, `Sendable`, no framework imports. Each one lives in a Lib target or GetClearKit and is tested there.

## Suite-wide (GetClearKit)

### `AccessRoute`
How a command reaches the stores.
- `.helper(appURL: URL)` — the executable resolves inside a `Get Clear.app`
- `.direct` — anything else (development build)
- `static func decide(resolvedExecutable: URL) -> AccessRoute`: pure, with no filesystem access. `.helper` when some ancestor path component is `Get Clear.app` and the executable sits in its `Contents/Helpers/`.

### `HelperEnvelope`
- `protocolVersion: Int` — bumped when the wire format changes incompatibly (starts at 1)
- `appVersion: String` — the suite version of the sender
- `request: Data` — a tool-specific encoded `*HelperRequest` (below)
- `tool: HelperTool` — `.reminders | .calendar | .contacts | .text | .getClear`

### `HelperReply`
- `.success(Data)` — encoded tool-specific result
- `.failure(HelperFailure)`

### `HelperFailure`
- `.accessDenied(StoreKind)` — maps to FR-005's message
- `.versionMismatch(helperProtocol: Int, helperApp: String)` — client restarts the helper and retries once
- `.storeError(message: String)` — a boundary error, carried as its `localizedDescription` and rethrown unchanged on the client, so stderr wording stays byte-identical (FR-014)
- `.badRequest(String)` — undecodable or unknown request (a defect, never user-caused)

### `StoreKind`
`.reminders | .calendars | .contacts | .messages`. One case per permission in FR-003. Carries `deniedMessage: String`:
`Get Clear doesn't have access to Reminders. Turn it on in System Settings → Privacy & Security → Reminders → Get Clear.`

### `InstalledApp`
- `url: URL`, `version: SemVer`, `writable: Bool`
- Built at the boundary from `Bundle(url:)` and `access(2)`; consumed by pure update decisions.

### `UpdatePlan` (decision, pure)
`static func decide(installed: InstalledApp?, latest: SemVer, appAsset: URL?, pkgAsset: URL) -> UpdatePlan`
- `.notInstalledAsApp` — dev build. Prints the existing "only available for PKG installs" message, unchanged.
- `.upToDate(SemVer)`
- `.selfUpdate(from:to:asset:)` — app writable and a `Get-Clear.zip` asset exists
- `.pkgFallback(from:to:asset:)` — not writable, or no zip asset

## Per tool (each `*Lib`)

One request enum and one result enum per store protocol. Each case mirrors one protocol method. The arguments are the protocol's existing value types, which gain `Codable`.

| Lib | Request enum | Cases (= protocol methods) |
|---|---|---|
| RemindersLib | `ReminderHelperRequest` | fetchLists, defaultList, fetchIncomplete(list), add(item), update(id, changes), complete(id), rename(id, title), delete(id) |
| CalendarLib | `CalendarHelperRequest` | fetchCalendars, fetchEvents(range, calendarIDs), add(item), remove(id) |
| ContactKit | `ContactHelperRequest` | fetchGroups, fetchContacts(group), add(draft), addToGroup(id, group), removeFromGroup(id, group), update(id, changes), rename(id, name), delete(id) |
| TextLib | `MessageHelperRequest` | send(query, message) |

Value types that gain `Codable` (today `Equatable`/`Sendable` only): `ReminderList`, `ReminderItem`, `ReminderChanges` (and its `ValueChange<T>` fields, so `ValueChange` gains a conditional `Codable` in GetClearKit), `CalendarItem`, `EventItem`, `AttendeeItem`, `ContactGroup`, `Contact`, `ContactField`, `ContactDraft`, `ContactChanges`, `SendResult`, plus `DateInterval` (already `Codable`).

### Remote stores (each `*Lib`)
`Remote*Store: *Store` — e.g. `RemoteReminderStore(transport: HelperTransport)`, where

```swift
public typealias HelperTransport = @Sendable (HelperEnvelope) async throws -> HelperReply
```

Each method encodes its request, calls `transport`, and decodes the reply or throws. Pure: tests inject a spy transport. No XPC here.

### Request dispatch (each `*Lib`)
`func dispatch(_ request: ReminderHelperRequest, to store: any ReminderStore) async throws -> Data`, the helper-side mirror of the remote store. It's pure over the protocol, so tests run it against a `SpyStore`. A round-trip test (`RemoteReminderStore` → envelope → `dispatch` → `SpyStore`) proves both halves agree for every method.

## get-clear's own access (`Sources/GetClear`)

`recap` and `setup` call EventKit directly today (#203). For FR-002 they move onto `CalendarStore` / `ReminderStore` through the same factories. This is the minimum seam #210 needs. #203's wider extraction stays #203's job.

## State transitions — helper lifecycle

```
not registered ──register──▶ registered/idle ──XPC connect──▶ running ──idle 60 s──▶ registered/idle
       ▲                         │   ▲                           │
       └──────unregister─────────┘   └──────kickstart -k (update / version mismatch)──┘
registered/idle ──user disables background item──▶ requiresApproval ──user re-enables──▶ registered/idle
```
