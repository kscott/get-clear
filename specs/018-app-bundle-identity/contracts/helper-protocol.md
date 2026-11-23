# Contract: CLI ↔ Helper

**Mach service**: `com.kenscott.get-clear.helper` (launchd agent label is the same)
**Peer requirement, both directions**: `anchor apple generic and certificate leaf[subject.OU] = "6Q96Q79QN8"`

## XPC interface

```swift
@objc protocol GetClearHelperXPC {
    func perform(_ envelope: Data, reply: @escaping (Data) -> Void)
}
```

`envelope` is a JSON-encoded `HelperEnvelope`; the reply is a JSON-encoded `HelperReply`. The interface never changes. New store methods add enum cases, not `@objc` methods.

## Guarantees

| # | Guarantee |
|---|---|
| C1 | A connection from a peer failing the requirement is invalidated before `perform` runs. |
| C2 | A `protocolVersion` or `appVersion` different from the helper's own → `.failure(.versionMismatch)`; no store is touched. |
| C3 | Every store request first ensures access for its `StoreKind`; denied → `.failure(.accessDenied(kind))`. The first-ever request for a kind triggers the system prompt in the helper. |
| C4 | A boundary error → `.failure(.storeError(localizedDescription))`. The client rethrows it so `fail()` prints the same text as a direct-access build. |
| C5 | Requests are independent; concurrent connections are served concurrently. |
| C6 | The helper does no work between requests and exits after 60 s idle (FR-007). |
| C7 | The helper never makes network requests (FR-007). |

## Client behavior

1. `AccessRoute.decide` → `.direct`: build today's in-process stores. This contract is not used.
2. `.helper`: connect, send.
   - Connection invalid or unreachable → run `<app>/Contents/MacOS/Get Clear register`, retry once. If it's still unreachable, fail with `Get Clear's background helper isn't running. Reinstall Get Clear from the PKG.`
   - `SMAppService` status `.requiresApproval` → fail with the Login Items message and open the settings pane.
   - `.versionMismatch` → `launchctl kickstart -k gui/<uid>/com.kenscott.get-clear.helper`, retry once.
   - `.accessDenied(kind)` → fail with `kind.deniedMessage`.

## App executable subcommands (internal; constitution: absent from usage)

| Invocation | Who calls it | Effect |
|---|---|---|
| `Get Clear serve` | launchd only | Run the XPC listener |
| `Get Clear register` | PKG postinstall; client self-heal | `SMAppService.agent(...).register()`; idempotent |
| `Get Clear unregister` | uninstaller | `unregister()`; idempotent |
| *(no arguments, e.g. double-click)* | Finder | Print or show "Get Clear runs from Terminal. Try `reminders --help`." and exit 0 |
