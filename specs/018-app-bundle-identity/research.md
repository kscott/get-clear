# Research: Get Clear App — Own Privacy Identity and Self-Update

**Feature**: 018-app-bundle-identity | **Date**: 2026-11-23

Each entry: **Decision**, **Rationale**, **Alternatives considered**. Entries marked **VERIFY IN SPIKE** rest on Apple forum guidance, not a guarantee, and are confirmed or overturned by task 0 (the spike) before anything else is built.

---

## R1. How a command gets an identity other than the terminal's

**Decision**: A launchd **agent registered with `SMAppService`**, whose program is the main executable of `Get Clear.app`, performs all protected-store access. The CLIs ask it over XPC.

**Rationale**: TCC attributes a request to the *responsible code*. A tool run from a terminal makes the terminal responsible; a process launched by launchd is responsible for itself; and for an agent installed through `SMAppService`, Apple DTS says the containing app becomes the responsible code, so the prompt and the stored decision belong to the app (bundle ID, name, icon, usage strings). An agent installed by other means needs `AssociatedBundleIdentifiers` and has reportedly behaved inconsistently across macOS versions. **VERIFY IN SPIKE** on macOS 27.2: `launchctl procinfo <helper pid>` shows `Get Clear.app` as responsible; the prompt names "Get Clear"; Privacy & Security lists "Get Clear".

**Alternatives considered**:
- *Self-disclaiming relaunch* (`responsibility_spawnattrs_setdisclaim`): one process, no IPC, but private SPI with no stability promise. Rejected 2026-11-23 in favor of the supported design.
- *Classic `/Library/LaunchAgents` plist + `AssociatedBundleIdentifiers`*: no `SMAppService` call needed, but attribution is the less reliable path and the plist lives outside the app, so self-update can't keep it in sync. Rejected.
- *CLIs inside the app bundle, no helper*: attribution still goes to the terminal. Does not fix #210.

## R2. Which executable is the helper

**Decision**: The helper is the app's **main executable** (`Get Clear.app/Contents/MacOS/Get Clear`), run by launchd as `Get Clear serve`. `Info.plist` sets `LSUIElement` (no Dock icon, no menu bar).

**Rationale**: Privacy prompts and Privacy & Security show the responsible app's name and icon. Making the main executable the agent means the identity *is* `Get Clear.app`, so FR-001's "named Get Clear" holds without a nested helper app showing up as "Get Clear Helper".

**Alternatives considered**: nested `Get Clear Helper.app` in `Contents/Library/LoginItems` (shows a second name in settings); a bare executable in `Contents/Helpers` as the agent (identity is a path or a custom-section bundle ID, the least reliable option).

## R3. Registering the agent

**Decision**: `SMAppService.agent(plistName: "com.kenscott.get-clear.helper.plist")`, plist in `Contents/Library/LaunchAgents/`, `BundleProgram` = `Contents/MacOS/Get Clear`, `ProgramArguments` = `["Get Clear", "serve"]`, `MachServices` = `{ com.kenscott.get-clear.helper: true }`. Registration is performed by the app executable itself (`Get Clear register` / `Get Clear unregister`), because `SMAppService` resolves the plist against the calling process's main bundle.
- PKG `postinstall` runs `register` in the console user's session (`launchctl asuser <uid> sudo -u <user> …`).
- **Self-heal**: when a CLI inside the app can't reach the helper, it runs `Get Clear register` once and retries (constitution: tools handle what they can). Covers a skipped postinstall, a reset, or a user who removed the background item.
- If `SMAppService.status` is `.requiresApproval`, the CLI fails with a message naming System Settings → General → Login Items & Extensions and opens it (`SMAppService.openSystemSettingsLoginItems()`). This is an OS security boundary, which the constitution allows.

**Rationale**: `BundleProgram` is only honored for `SMAppService`-installed plists, and the plist is inside the bundle, so self-update replaces it with the app. **VERIFY IN SPIKE**: the registration survives replacing the bundle at the same path; whether registration posts a "Background item added" notification or needs approval on 27.2.

## R4. Transport and peer validation

**Decision**: `NSXPCConnection(machServiceName: "com.kenscott.get-clear.helper")` from the CLI; `NSXPCListener(machServiceName:)` in the helper. One `@objc` method carries an opaque request: `perform(_ request: Data, reply: (Data) -> Void)`. Both sides call `setCodeSigningRequirement` (macOS 13+) with:

```
anchor apple generic and certificate leaf[subject.OU] = "6Q96Q79QN8"
```

(Team ID quoted — an unquoted Team ID traps inside `setCodeSigningRequirement`, per DTS.) Verified first with `codesign -R`.

**Rationale**: FR-008. A single opaque `Data` method keeps every request type a plain `Codable` value in the Lib targets, so the whole wire format is pure and unit-testable, and the `@objc` surface never changes as stores evolve.

**Alternatives**: per-store `@objc` protocols with `NSSecureCoding` classes (forces framework-style classes into Lib, violates the layer model); `xpc_connection_*` C API (more code, same capability); a Unix socket (no free peer validation).

## R5. Messages (Automation)

**Decision**: Unchanged `osascript` dispatch, run by the helper. The app is signed with the hardened runtime and the `com.apple.security.automation.apple-events` entitlement; `Info.plist` carries `NSAppleEventsUsageDescription`.

**Rationale**: `osascript` launched by the helper has the helper as responsible code, so the Automation prompt names Get Clear. Under the hardened runtime, sending Apple Events requires that entitlement. **VERIFY IN SPIKE** (Automation is a separate TCC service from the other three).

## R6. Usage descriptions and entitlements

**Decision**: `Info.plist` keys: `NSRemindersFullAccessUsageDescription`, `NSCalendarsFullAccessUsageDescription`, `NSContactsUsageDescription`, `NSAppleEventsUsageDescription`. Entitlements on the app executable: `com.apple.security.automation.apple-events`, plus the existing `personal-information.calendars` / `.reminders` (carried from `get-clear.entitlements`), plus `personal-information.addressbook`. Not sandboxed. The CLIs in `Contents/Helpers` get no privacy entitlements and request nothing.

**Rationale**: FR-003: exactly four permissions. CLIs requesting nothing keeps the identity single (FR-001).

## R7. Wire format and versioning

**Decision**: `HelperEnvelope { protocolVersion: Int, appVersion: String, request: HelperRequest }` / `HelperReply { result | error }`, JSON-encoded. `HelperRequest` is an enum with one case per store method (21 today) plus `requestAccess(Store)` and `ping`. On `protocolVersion` or `appVersion` mismatch the helper replies `.versionMismatch(helper:)`; the client runs `launchctl kickstart -k gui/<uid>/com.kenscott.get-clear.helper` and retries once.

**Rationale**: FR-019 and the version-skew edge case. JSON so a failing exchange is readable in a log.

## R8. Self-update

**Decision**: Each release publishes `get-clear.pkg` (first install, fallback, and what 1.3.x's updater downloads) **and** `Get-Clear.zip` (the notarized, stapled app, made with `ditto -c -k --keepParent`). `get-clear update` (PKG installs in a writable location):
1. Download `Get-Clear.zip` into a staging directory **on the same volume** as the installed app (a sibling of the app, removed on every exit path).
2. `ditto -x -k` into it.
3. Verify with `SecStaticCodeCheckValidity` (all-architectures, strict) against `anchor apple generic and identifier "com.kenscott.get-clear" and certificate leaf[subject.OU] = "6Q96Q79QN8" and notarized`. Check the staged `CFBundleShortVersionString` is newer than the installed one.
4. Swap atomically: `renamex_np(staged, installed, RENAME_SWAP)`. Both paths are on one APFS volume, so at every instant one complete bundle is at the installed path (FR-018).
5. `launchctl kickstart -k` the agent so no old helper serves new CLIs (FR-019).
6. Delete the swapped-out old bundle.

When the app's directory is not writable, fall back to today's PKG download-and-open flow, saying so (FR-021).

**Rationale**: The `notarized` requirement clause plus the team and identifier check covers FR-017 in one call. `RENAME_SWAP` is the only atomic directory replace on APFS. `FileManager.replaceItemAt` is not atomic for directories. TCC grants survive because the designated requirement (identifier + team) doesn't change between releases (DTS: same DR means the same app).

**Alternatives**: Sparkle (built for GUI apps, needs its own feed and keys; out of scope per spec); re-running the PKG every time (password + Installer on every update, the experience this feature removes).

## R9. Installed version and the update hint

**Decision**: `UpdateChecker.installedVersion()` reads `CFBundleShortVersionString` from the `Get Clear.app` that contains the running executable, found by resolving the executable path through its symlink (`realpath` on `_NSGetExecutablePath`). The background check runs only when that resolves to an app bundle. It no longer uses the `pkgutil` receipt.

**Rationale**: After a self-update the PKG receipt still names the old version, so a receipt-based check would show the hint forever (violates FR-015 and US3 scenario 8). "Am I inside the app?" also replaces "is there a receipt?" as the dev-machine test.

## R10. Development fallback

**Decision**: A pure `AccessRoute` decision in GetClearKit: executable resolves inside a `Get Clear.app` → `.helper`; otherwise → `.direct`. `.direct` builds today's Apple stores in-process, with no added output (FR-025).

**Rationale**: Testable with no app or permissions present. Dev builds keep today's terminal-attributed behavior and never touch signing.

## R11. App assembly without Xcode

**Decision**: `scripts/build-app` creates `Get Clear.app` from `swift build -c release` output: the main executable (new `GetClearApp` target) goes in `Contents/MacOS/Get Clear`, the six CLIs in `Contents/Helpers/<tool>`, plus `Info.plist`, the agent plist, the icon, and zsh completions in `Contents/Resources`. Signing is inside-out: each helper (`--identifier com.kenscott.get-clear.<tool>`), then the app with its entitlements. Hardened runtime and a timestamp on all. CI and local builds use the same script.

**Rationale**: SwiftPM builds executables, not bundles. One script means CI and local builds can't drift.

## R12. PATH and uninstall

**Decision**: The PKG payload carries `/Applications/Get Clear.app` and six symlinks `/usr/local/bin/<tool> → /Applications/Get Clear.app/Contents/Helpers/<tool>`. Installing the payload over 1.3.x replaces the old binaries at those paths. `scripts/uninstall` runs `Get Clear unregister`, then removes the app, the symlinks, the completions and the receipt. It ends by printing `tccutil reset All com.kenscott.get-clear` as the way to clear privacy decisions (FR-024).

## App icon (resolved)

- `assets/GetClear.svg` is the source: a white cloud with a check, on a steel blue-gray gradient. `scripts/build-icon` renders it into `assets/GetClear.icns` with `rsvg-convert` (`brew install librsvg`) and `iconutil`. The `.icns` is committed, so `scripts/build-app` and CI don't need librsvg.

## Sources

- [Apple Developer Forums 732291 — Signing ID of command-line helpers](https://developer.apple.com/forums/thread/732291)
- [The Curious Case of the Responsible Process (Qt)](https://www.qt.io/blog/the-curious-case-of-the-responsible-process)
- [ghostty #9263 — launchd process is its own responsible process](https://github.com/ghostty-org/ghostty/issues/9263)
- [launchd.plist(5) — BundleProgram, MachServices](https://keith.github.io/xcode-man-pages/launchd.plist.5.html)
- [Apple Developer Forums 722932 — SMAppService.agent register](https://developer.apple.com/forums/thread/722932)
- [Building a Modern Launch Agent on macOS (gist)](https://gist.github.com/Matejkob/f8b1f6a7606f30777552372bab36c338)
- [Apple Developer Forums 801478 — XPC codesign requirement crash, quote the Team ID](https://developer.apple.com/forums/thread/801478)
- [xpc_connection_set_peer_team_identity_requirement](https://developer.apple.com/documentation/xpc/xpc_connection_set_peer_team_identity_requirement(_:_:).md)
- [TN3127 — Inside Code Signing: Requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements.md)
- [Apple Developer Forums 785384 — permissions follow the designated requirement](https://developer.apple.com/forums/thread/785384)
- [Apple Developer Forums 795739 — ad hoc signing loses permissions on update](https://developer.apple.com/forums/thread/795739)
