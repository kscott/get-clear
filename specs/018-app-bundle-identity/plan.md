# Implementation Plan: Get Clear App — Own Privacy Identity and Self-Update

**Branch**: `018-app-bundle-identity` | **Date**: 2026-11-23 | **Spec**: [spec.md](spec.md) | **Issue**: #210
**Input**: Feature specification from `/specs/018-app-bundle-identity/spec.md`

## Summary

Every Get Clear command that touches Reminders, Calendars, Contacts, or Messages gets its permission under the terminal's identity, so under a terminal with no usage strings (Tecolot) every request is silently denied. Fix: ship the suite as one signed, notarized `Get Clear.app`. Its main executable runs as a launchd agent registered with `SMAppService`, which makes the app the responsible code for TCC. That agent alone performs store access. The six CLIs live in `Contents/Helpers/`, are on PATH through `/usr/local/bin` symlinks, and send each store call to the agent over XPC as a `Codable` request. A development build, which has no app around it, keeps today's direct access. Updates after the first PKG install swap a notarized `Get-Clear.zip` into place atomically, after a signature check, with no Installer and no password.

The store protocols already exist and pass plain value types (the three-tier work), so each Lib gains a `Remote*Store` (client) and a `dispatch` function (helper side), both pure. No handler changes.

## Technical Context

**Language/Version**: Swift 6.0 (swift-tools-version 6.0, language mode v5)
**Primary Dependencies**: Foundation (`NSXPCConnection`, `NSXPCListener`), ServiceManagement (`SMAppService`, in the app target only), Security (`SecStaticCode`, in the update boundary only). The existing EventKit / Contacts boundary targets are reused unchanged inside the helper.
**Storage**: None new. The existing update cache stays.
**Testing**: Swift Testing via `./scripts/test`. Every new Lib/GetClearKit file is pure and spec'd, including a remote→dispatch round-trip per store method. The XPC, SMAppService, signing, and TCC behavior is verified by the spike and the quickstart acceptance runs, not unit tests.
**Target Platform**: macOS 14+ (unchanged; `setCodeSigningRequirement` needs 13+, `SMAppService` 13+). Apple silicon builds, as today.
**Project Type**: CLI suite (monorepo) plus one new app target.
**Performance Goals**: SC-006: under 0.5 s for commands that are under 0.5 s today, measured with the helper cold.
**Constraints**: Lib and GetClearKit stay framework-free. No new flags. No handler signature changes. stdout byte-identical (FR-014). Helper does no unrequested work and no network (FR-007).
**Scale/Scope**: 21 store methods across 4 protocols, plus `requestAccess` and `ping`. 6 CLIs. 1 new executable target (`GetClearApp`), 1 new boundary target (`HelperXPC`). Roughly 14 new pure source files with specs. `get-clear`'s `recap`/`setup` move onto the store factories (minimum seam for FR-002; the rest of #203 stays out). CI release job reworked. PKG payload and postinstall reworked. Uninstaller extended.

## Constitution Check

*GATE: passes before Phase 0. Re-checked after Phase 1 design: still passes.*

| Rule | Status | Notes |
|------|--------|-------|
| Tools handle what they can | ✓ PASS | Client self-registers the helper and restarts it on version mismatch. Only OS boundaries reach the user: the permission prompt, Login Items approval, and the PKG password in the non-writable fallback. |
| No flags | ✓ PASS | None added. The app executable takes subcommands (`serve`, `register`, `unregister`). |
| No silent failures | ✓ PASS | Every helper failure maps to a named stderr message and non-zero exit (contract C2–C4, client behavior). Verification failure leaves the install untouched and says so. |
| Stdout / stderr split | ✓ PASS | Update progress goes to stderr. Store errors rethrow with identical text. |
| Add and remove ship together | ✓ N/A | No new commands |
| Read-only commands never write | ✓ PASS | Read-only commands may *start* the helper and register it on first use. That's process lifecycle, not data. It's called out so review can confirm it fits the "caches explicitly part of their design" allowance. |
| The vocabulary is fixed | ✓ PASS | `update` existing; app subcommands internal |
| Setup is idempotent | ✓ PASS | `register`/`unregister` idempotent; PKG reinstall idempotent (FR-013) |
| Internal commands absent from usage() | ✓ PASS | `serve`/`register`/`unregister` are never listed |
| Phoning home requires consent | ✓ PASS | No new network traffic beyond the existing update check/download; the helper makes none |
| Color has exactly three levels | ✓ PASS | New messages are plain text plus the existing red `Error:` |
| GetClearKit first | ✓ PASS | Envelope, `AccessRoute`, `UpdatePlan`, and the transport typealias live in GetClearKit; each Lib owns only its own request enum, remote store, and dispatch |
| Tests are Swift Testing | ✓ PASS | All new pure files have `*Spec.swift` in the same commit |
| Timestamps from system clock | ✓ N/A | |

## Project Structure

### Documentation (this feature)

```text
specs/018-app-bundle-identity/
├── plan.md               # this file
├── research.md           # R1–R12: decisions, rationale, sources; items marked VERIFY IN SPIKE
├── data-model.md         # value types, request enums, remote stores, lifecycle
├── quickstart.md         # spike procedure (gate) + acceptance runs
├── contracts/
│   ├── helper-protocol.md   # CLI ↔ helper XPC contract
│   └── cli-update.md        # get-clear update + hint contract
└── tasks.md              # /speckit.tasks — not yet
```

### Source Code (repository root)

```text
Sources/
├── GetClearKit/
│   ├── AccessRoute.swift            # NEW pure: helper vs direct decision
│   ├── HelperEnvelope.swift         # NEW pure: envelope, reply, failure, StoreKind, transport typealias
│   ├── UpdatePlan.swift             # NEW pure: update decision
│   ├── UpdateChecker.swift          # CHANGED: installed version from app bundle, not pkgutil
│   └── ValueChange.swift            # CHANGED: conditional Codable
├── HelperXPC/                       # NEW boundary: NSXPCConnection client, NSXPCListener service,
│   ├── HelperClient.swift           #   peer requirement, register-and-retry, kickstart
│   └── HelperService.swift
├── GetClearApp/                     # NEW executable → Contents/MacOS/Get Clear
│   ├── main.swift                   #   dispatch: serve | register | unregister | (none)
│   └── Info.plist, *.entitlements, com.kenscott.get-clear.helper.plist
├── GetClear/
│   ├── UpdateCommand.swift          # CHANGED: UpdatePlan → self-update or PKG fallback
│   ├── SelfUpdater.swift            # NEW boundary: download, ditto, SecStaticCode verify, RENAME_SWAP
│   ├── RecapAggregator.swift        # CHANGED: stores via factories, not EKEventStore
│   └── SetupCommand.swift           # CHANGED: access via factory
├── ContactKit/
│   ├── ContactHelperRequest.swift   # NEW pure
│   ├── RemoteContactStore.swift     # NEW pure
│   └── ContactDispatch.swift        # NEW pure
└── ContactStoreFactory/StoreFactory.swift   # CHANGED: AccessRoute → remote or direct
reminders-cli/Sources/
├── RemindersLib/{ReminderHelperRequest,RemoteReminderStore,ReminderDispatch}.swift   # NEW pure
└── RemindersCLI/StoreFactory.swift                                                   # CHANGED
calendar-cli/Sources/
├── CalendarLib/{CalendarHelperRequest,RemoteCalendarStore,CalendarDispatch}.swift    # NEW pure
└── CalendarCLI/StoreFactory.swift                                                    # CHANGED
text-cli/Sources/
├── TextLib/{MessageHelperRequest,RemoteMessageSender,MessageDispatch}.swift          # NEW pure
└── TextCLI/StoreFactory.swift                                                        # CHANGED
Tests/…                              # one *Spec.swift per NEW/CHANGED pure file
scripts/build-app                    # NEW: assemble + sign Get Clear.app (local and CI)
scripts/uninstall                    # CHANGED: unregister, remove app + symlinks
pkg/scripts/postinstall              # CHANGED: register helper in the console user's session
.github/workflows/release.yml        # CHANGED: build-app, notarize + staple app, zip, PKG with app + symlinks
assets/GetClear.icns                 # NEW (placeholder acceptable; see research "Open dependency")
```

**Structure Decision**: Follow the existing three-tier layout. Each pure wire type sits next to the protocol it mirrors (in the Lib), so a future backend or store method changes one Lib. XPC and ServiceManagement are framework code, so they get their own boundary target (`HelperXPC`) and the app target, keeping GetClearKit Foundation-only and framework-free in the sense the layer model means. `mail` gains nothing new. Its Contacts lookups go through `ContactStoreFactory`, which routes them automatically.

## Delivery order

0. **Spike (gate)**: quickstart §0, including the run from Tecolot on the work Mac. Stop and report if attribution isn't the app.
1. Pure layer: `AccessRoute`, envelope, `Codable` value types, the 4 request enums, remote stores, dispatchers, `UpdatePlan`, with round-trip specs. Nothing user-visible changes yet.
2. `HelperXPC` + `GetClearApp` + `scripts/build-app`. Factories route through `AccessRoute`. Locally, US1 works from a built app.
3. `get-clear` `recap`/`setup` onto factories.
4. Self-update (`SelfUpdater`, `UpdateCommand`, `UpdateChecker`).
5. PKG, postinstall, uninstaller, release workflow. Cut a pre-release tag and run quickstart §2 end to end, including 1.3.5 → new via the old updater (FR-022).
6. Docs: ARCHITECTURE.md decision entries (helper model, wire format, self-update), README install and permissions text, spec 005 status note.

## Risks

| Risk | Mitigation |
|---|---|
| SMAppService attribution differs on 27.2 from DTS guidance (R1) | Spike gate before step 1; the design stops there if it fails |
| Registration needs user approval in Login Items | Handled as an OS boundary: clear message and the settings pane opened (contract) |
| Hardened runtime blocks Apple Events | `automation.apple-events` entitlement (R5); spike step 6 |
| Self-update leaves a half-installed app | `RENAME_SWAP` on one volume; staging next to the app; cleanup on every path |
| 1.3.x updater can't reach the new layout | `get-clear.pkg` keeps its asset name; payload overwrites the old binary paths with symlinks |
| Helper cold start pushes commands past 0.5 s | Measured in step 2 against SC-006; on-demand launch, no warmup work |

## Complexity Tracking

No constitution violations. One new executable target and one new boundary target are inherent to the fix: a second process is required for a second identity (research R1), and framework code stays out of GetClearKit.
