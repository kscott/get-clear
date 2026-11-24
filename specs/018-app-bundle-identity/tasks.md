# Tasks: Get Clear App — Own Privacy Identity and Self-Update

**Input**: Design documents from `/specs/018-app-bundle-identity/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓, quickstart.md ✓
**Issue**: #210

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel with other [P] tasks in the same phase (different files, no dependency on an incomplete task)
- **[Story]**: Which user story this task most delivers
- All file paths are relative to the monorepo root

**Tests**: Included. The project requires one `*Spec.swift` per source file, shipped in the same commit (review.md, CLAUDE.md), and Lib logic is written interface-first. XPC, `SMAppService`, signing, and TCC behavior can't be unit-tested; the spike and quickstart §2 verify them.

---

## Phase 1: Setup and the spike (gate)

**⚠️ GATE**: Nothing in Phase 2 or later starts until T007 passes. If the spike shows the terminal, not the app, as responsible, stop and bring the result to Ken. The design rests on research R1.

- [X] T001 Merge `main` into `018-app-bundle-identity`, run `./scripts/test`, and record the pass count as the baseline.
- [X] T002 Build a throwaway spike **outside the repo** (`/tmp/get-clear-spike/`): a SwiftPM package with two executables. `Spike` (the agent): `serve` runs an `NSXPCListener(machServiceName: "com.kenscott.spike.helper")` with the contract's single `perform(Data) -> Data` method, which calls `EKEventStore().requestFullAccessToReminders()` and replies with the result and the count of reminder lists; `register`/`unregister` call `SMAppService.agent(plistName:)`. `spike-client`: connects to the Mach service, sends one request, prints the reply. Both set `setCodeSigningRequirement("anchor apple generic and certificate leaf[subject.OU] = \"6Q96Q79QN8\"")`.
- [X] T003 Assemble `Spike.app` by hand: `Contents/MacOS/Spike`, `Contents/Helpers/spike-client`, `Info.plist` (`CFBundleIdentifier com.kenscott.spike`, `LSUIElement`, `NSRemindersFullAccessUsageDescription`, `NSAppleEventsUsageDescription`), `Contents/Library/LaunchAgents/com.kenscott.spike.helper.plist` (`BundleProgram`, `ProgramArguments [Spike, serve]`, `MachServices`). Sign inside-out with `Developer ID Application: Kenneth Scott (6Q96Q79QN8)`, `--options runtime --timestamp`, entitlements `personal-information.reminders` and `automation.apple-events`. Copy to `/Applications`.
- [X] T004 On primo (quickstart §0 steps 2–3): `Spike register`, then run `/Applications/Spike.app/Contents/Helpers/spike-client` from Terminal. Record: the prompt's wording, `sudo launchctl procinfo <agent pid> | grep responsible`, and what Privacy & Security → Reminders lists. Also record whether registering posted a "Background item added" notification or needed approval in Login Items. Ken clicks the prompt.
- [X] T005 Bundle replacement (quickstart §0 step 5): bump `CFBundleShortVersionString`, re-sign, swap the bundle in with a small `renamex_np(RENAME_SWAP)` helper, `launchctl kickstart -k gui/$UID/com.kenscott.spike.helper`, rerun the client. Expect no new prompt and the registration intact.
- [X] T006 Automation (quickstart §0 step 6): add a `messages` request to the spike that runs `osascript -e 'tell application "Messages" to get name'`. Expect the Automation prompt to name Spike.
- [X] T007 **Go/no-go** (passed on primo; work Mac run waived by Ken 2026-11-23, see research → Spike results): zip `Spike.app` with `ditto -c -k --keepParent`, notarize it with `xcrun notarytool submit --wait` (or, if no local notary credentials, document that `xattr -dr com.apple.quarantine` was used), and have Ken run T004's steps from **Tecolot on the work Mac**. Write the results (pass/fail per check, macOS build, screenshots referenced) into a new `## Spike results` section at the end of `specs/018-app-bundle-identity/research.md`, and update every **VERIFY IN SPIKE** marker to the observed outcome. Commit and push.

**Checkpoint**: Ken confirms the go. Delete `/tmp/get-clear-spike/` and `Spike register`'s registration (`Spike unregister`, then remove `/Applications/Spike.app`) on both Macs.

---

## Phase 2: Foundational — the wire layer (pure)

**Purpose**: Every value that crosses the XPC boundary, as pure `Codable` types with specs. No user-visible change. All four stories depend on this phase.

- [X] T008 Create `Sources/GetClearKit/HelperEnvelope.swift`: `HelperTool`, `HelperEnvelope`, `HelperReply`, `HelperFailure` (including `.toolError(Data)`), `StoreKind` with `deniedMessage`, `HelperControlRequest` (`ping`, `requestAccess(StoreKind)`), the `HelperTransport` typealias, and `static let protocolVersion = 1`. All `Codable, Equatable, Sendable`. Shapes from `data-model.md`.
- [X] T009 Create `Tests/GetClearKitTests/HelperEnvelopeSpec.swift`: JSON round-trip for an envelope and for each `HelperReply`/`HelperFailure` case; each `StoreKind.deniedMessage` names its permission and "Get Clear" in FR-005's form.
- [X] T008a Create `Sources/GetClearKit/HelperExchange.swift`: `HelperCoding` (one JSON format for both sides), `HelperNoResult`, `HelperStoreError` (exact-text rethrow), `HelperCallError`, `HelperCaller` (command side: encode, send, decode, map each `HelperFailure` to a thrown error), `HelperResponder` (helper side: decode, run, wrap the result or error). Every tool's remote store and dispatch is built on these, so encoding and error mapping exist once. Spec `Tests/GetClearKitTests/HelperExchangeSpec.swift` wires caller → responder back to back.
- [X] T010 [P] Create `Sources/GetClearKit/AccessRoute.swift`: `decide(resolvedExecutable:) -> AccessRoute` per data-model (pure path logic, no filesystem), plus `appURL` on `.helper`.
- [X] T011 [P] Create `Tests/GetClearKitTests/AccessRouteSpec.swift`: inside `/Applications/Get Clear.app/Contents/Helpers/` → helper; inside a renamed app (`Get Clear 2.app`) → direct; `.build/release/reminders-bin` → direct; `Contents/MacOS/Get Clear` itself → direct (the app executable never routes to itself); an app at a non-`/Applications` path (`~/Applications`) → helper.
- [X] T012 [P] Update `Sources/GetClearKit/ValueChange.swift`: conditional `extension ValueChange: Codable where T: Codable`. Extend `Tests/GetClearKitTests/ValueChangeSpec.swift` with a round-trip `@Test` per case.
- [X] T013 [P] Add `Codable` to the reminders value types and their nested types: `ReminderList` (`reminders-cli/Sources/RemindersLib/ReminderList.swift`), `ReminderItem` (`ReminderItem.swift`), `ReminderChanges` (`ReminderChangeParsing.swift`), and `ReminderStoreError` (`ReminderStore.swift`). Add one round-trip `@Test` per type to each type's existing spec file in `reminders-cli/Tests/RemindersLibTests/`, populated with every optional field set.
- [X] T014 [P] Add `Codable` to `CalendarItem`, `EventItem`, `AttendeeItem` (`calendar-cli/Sources/CalendarLib/EventItem.swift`) and `CalendarStoreError` (`CalendarStore.swift`). Round-trip `@Test`s in `calendar-cli/Tests/CalendarLibTests/EventItemSpec.swift` and `CalendarStoreSpec.swift`.
- [X] T015 [P] Add `Codable` to `ContactGroup`, `Contact`, `ContactField`, `ContactDraft`, `ContactChanges`, and `ContactStoreError` (`Sources/ContactKit/`). Round-trip `@Test`s in each type's spec under `Tests/ContactKitTests/`. (None of these source files had a spec; each now does, and `ContactStoreSpec` also pins `ContactStoreError`'s wording.)
- [X] T016 [P] Add `Codable` to `SendResult` (`text-cli/Sources/TextLib/MessageSender.swift`). Round-trip `@Test` in `text-cli/Tests/TextLibTests/MessageSenderSpec.swift` (create it if absent).

**Checkpoint**: `./scripts/test` green; counts up by the new specs. Commit per task with its spec.

---

## Phase 3: User Story 1 — works under any terminal (P1) 🎯 MVP

**Goal**: An installed `Get Clear.app` performs all store access through its helper; every CLI inside the app routes there. Locally, a built and signed app works from Tecolot.

**Independent Test**: `./scripts/build-app`, copy to `/Applications`, run `Get Clear register`, then from Tecolot run `"/Applications/Get Clear.app/Contents/Helpers/reminders" lists`: one prompt naming Get Clear, then the lists. Repeat for `calendar today`, `contacts find a`, `text send <self> message test`, `get-clear recap`.

### Per-tool wire pieces (pure, each with specs)

- [X] T017 [P] [US1] Add `fetchCompleted(in: DateInterval) async throws -> [ReminderItem]` to `ReminderStore` (`reminders-cli/Sources/RemindersLib/ReminderStore.swift`) and implement it in `reminders-cli/Sources/RemindersEventKit/AppleReminderStore.swift` (move recap's completed-in-range filter there). Add it to any reminder spy/test store. Update `ReminderStoreSpec.swift`.
- [X] T018 [US1] Create `reminders-cli/Sources/RemindersLib/ReminderHelperRequest.swift` (one case per `ReminderStore` method, 9 including `fetchCompleted`), `RemoteReminderStore.swift` (`ReminderStore` over a `HelperTransport`: encode, send, decode, rethrow `.toolError` as `ReminderStoreError` and `.storeError` with its exact text), and `ReminderDispatch.swift` (`dispatch(_:to:) async throws -> Data`, mapping `ReminderStoreError` to `.toolError`).
- [X] T019 [US1] Create `reminders-cli/Tests/RemindersLibTests/ReminderHelperRequestSpec.swift`, `RemoteReminderStoreSpec.swift`, `ReminderDispatchSpec.swift`. The round-trip suite wires `RemoteReminderStore` → a transport that calls `dispatch` → a spy store, one `@Test` per method, proving arguments arrive and results return intact. Plus: a typed `ReminderStoreError.notFound` thrown by the spy reaches the caller as the same typed value; a non-typed error reaches the caller with an identical `localizedDescription`.
- [X] T020 [P] [US1] Calendar: add user-owned flag to `CalendarItem` (done as `CalendarKind` with a pure `isUserOwned`, so the decision lives in Lib, not the boundary) (set in `calendar-cli/Sources/CalendarEventKit/AppleCalendarStore.swift` from `EKCalendar.type` local/CalDAV/Exchange). Create `calendar-cli/Sources/CalendarLib/CalendarHelperRequest.swift`, `RemoteCalendarStore.swift`, `CalendarDispatch.swift`, with specs `CalendarHelperRequestSpec.swift`, `RemoteCalendarStoreSpec.swift`, `CalendarDispatchSpec.swift` in `calendar-cli/Tests/CalendarLibTests/` (same shape as T018–T019; 4 methods; typed `CalendarStoreError` round-trip).
- [X] T021 [P] [US1] Contacts: create `Sources/ContactKit/ContactHelperRequest.swift`, `RemoteContactStore.swift`, `ContactDispatch.swift`, with specs in `Tests/ContactKitTests/` using the existing `SpyContactStore` from `Tests/ContactTestSupport/` (8 methods; typed `ContactStoreError` round-trip).
- [X] T022 [P] [US1] Text: create `text-cli/Sources/TextLib/MessageHelperRequest.swift`, `RemoteMessageSender.swift`, `MessageDispatch.swift`, with specs in `text-cli/Tests/TextLibTests/` (1 method). `TextError` gains `Codable` and travels typed, like the other tools' store errors.

### Boundary: XPC and the app

- [X] T023 [US1] Create the `HelperXPC` library target in `Package.swift` (depends on `GetClearKit`) with `Sources/HelperXPC/HelperClient.swift`: `makeTransport(appURL:) -> HelperTransport` over `NSXPCConnection(machServiceName: "com.kenscott.get-clear.helper")` with the peer requirement from `contracts/helper-protocol.md`; on unreachable, run `<app>/Contents/MacOS/Get Clear register` and retry once; on `.versionMismatch`, `launchctl kickstart -k gui/<uid>/com.kenscott.get-clear.helper` and retry once; on `.accessDenied(kind)`, `fail(kind.deniedMessage)`; on still unreachable, fail with the contract's reinstall message. Every envelope carries `HelperEnvelope.protocolVersion` and `suiteVersion`.
- [X] T024 [US1] Create `Sources/HelperXPC/HelperService.swift`: `NSXPCListener` delegate that sets the peer requirement, decodes each envelope, enforces C2 (version match) and C3 (ensure access for the tool's `StoreKind` first, prompting on first use), routes by `HelperTool` to a dispatch closure supplied by the caller, and encodes the reply. Concurrent connections served concurrently (C5). An idle timer exits the process after 60 s with no open connection (C6). (The C2/C3/route decision is pure in `Sources/GetClearKit/HelperGate.swift` with `HelperGateSpec`; each request declares the permissions it needs, so `text` to a phone number never asks for Contacts.)
- [X] T025 [US1] Create the `GetClearApp` executable target in `Package.swift` (product name `get-clear-app`) depending on `HelperXPC`, the four Libs, and the existing boundary targets (`RemindersEventKit`, `CalendarEventKit`, `AppleContactKit`, `TextMessages`). `Sources/GetClearApp/main.swift` is dispatch-only: `serve` → `HelperService` with each tool's `dispatch` bound to the Apple store; `register` / `unregister` → `SMAppService.agent(plistName: "com.kenscott.get-clear.helper.plist")`, idempotent, printing the resulting status; no arguments → the contract's "Get Clear runs from Terminal" message, exit 0; anything else → usage to stderr, exit 1. `SMAppService` status `.requiresApproval` → the Login Items message, `SMAppService.openSystemSettingsLoginItems()`, exit 1.
- [X] T026 [P] [US1] Create `Sources/GetClearApp/Info.plist` (`CFBundleIdentifier com.kenscott.get-clear`, `CFBundleName`/`CFBundleDisplayName` "Get Clear", `CFBundleExecutable` "Get Clear", `CFBundleIconFile` GetClear, `LSUIElement` true, `LSMinimumSystemVersion` 14.0, version keys filled by `build-app`, and the four usage strings from FR-003 in plain language), `Sources/GetClearApp/GetClearApp.entitlements` (`personal-information.calendars`, `.reminders`, `.addressbook`, `automation.apple-events`), and `Sources/GetClearApp/com.kenscott.get-clear.helper.plist` (`Label`, `BundleProgram Contents/MacOS/Get Clear`, `ProgramArguments [Get Clear, serve]`, `MachServices`). Exclude these from the target's sources in `Package.swift`.
- [X] T027 [US1] Create `scripts/build-app` (bash, house style of `scripts/lint`): `swift build -c release --arch arm64`; assemble `.build/Get Clear.app` (`Contents/MacOS/Get Clear` ← `get-clear-app`; `Contents/Helpers/{get-clear,reminders,calendar,contacts,mail,text}` ← the built products; `Info.plist` with `CFBundleShortVersionString`/`CFBundleVersion` from `VERSION`; the agent plist in `Contents/Library/LaunchAgents/`; `assets/GetClear.icns` in `Contents/Resources/`; completions in `Contents/Resources/completions/`); sign inside-out with `--options runtime --timestamp`, each CLI keeping its 1.3.x signing identifier (research R11; record the identifiers from a 1.3.5 install in the script's header comment) and `get-clear` keeping `Sources/GetClear/get-clear.entitlements`, then the app with `GetClearApp.entitlements`; finish with `codesign --verify --deep --strict` and `codesign -R='anchor apple generic and certificate leaf[subject.OU] = "6Q96Q79QN8"'`. Signing identity comes from `$SIGN_IDENTITY`, defaulting to `Developer ID Application: Kenneth Scott (6Q96Q79QN8)`. `git update-index --chmod=+x`.

### Routing the factories

- [X] T028 [US1] Move `makeReminderStore` into a new `ReminderStoreFactory` library target (`reminders-cli/Sources/ReminderStoreFactory/StoreFactory.swift`), and `makeCalendarStore` into `CalendarStoreFactory` (`calendar-cli/Sources/CalendarStoreFactory/StoreFactory.swift`). Delete the old `StoreFactory.swift` files from `RemindersCLI`/`CalendarCLI`; update `Package.swift` dependencies so `reminders-bin` and `calendar-bin` import the new targets. No behavior change; `./scripts/test` green.
- [X] T029 [US1] Route all four factories through `AccessRoute`: `reminders-cli/Sources/ReminderStoreFactory/StoreFactory.swift`, `calendar-cli/Sources/CalendarStoreFactory/StoreFactory.swift`, `Sources/ContactStoreFactory/StoreFactory.swift`, `text-cli/Sources/TextCLI/StoreFactory.swift`. `.direct` keeps today's code path exactly, including today's denied messages (FR-025). `.helper(appURL)` returns `Remote*Store(transport: makeTransport(appURL:))`. The resolved executable path comes from a single boundary helper in `HelperXPC` (`realpath` of `_NSGetExecutablePath`). `text` in helper mode sends `MessageHelperRequest.send` and does no contact lookup itself (the helper's `AppleMessageSender` does).

### get-clear's own access (minimum seam for FR-002)

- [X] T030 [US1] Move `Sources/GetClear/RecapAggregator.swift` onto `CalendarStore` and `ReminderStore`: take the two stores (from the factories) instead of `EKEventStore`; calendar resolution filters `CalendarItem` by name or by the user-owned flag; events come from `fetchEvents(in:calendarIdentifiers:)`, keeping the existing past-event and all-day rules and dedup; completed reminders from `fetchCompleted(in:)`. Update `Sources/GetClear/RecapFormatter.swift` and `RecapCommand.swift` to work on `EventItem`/`ReminderItem` and drop `import EventKit`. Update the existing recap specs in `Tests/GetClearTests/` to build value types instead of EventKit objects. Output byte-identical (FR-014): diff `get-clear recap` before and after on primo.
- [X] T031 [US1] Move `Sources/GetClear/SetupCommand.swift` onto `makeCalendarStore()`; drop `import EventKit` from the `GetClear` target. Output unchanged.
- [X] T032 [US1] Local acceptance (done on primo through the installed PKG; results in research → Local acceptance. The Tecolot run rides on the work-Mac update) (quickstart §1 and §2 US1): build the app, copy to `/Applications`, `Get Clear register`, run the Independent Test above from Tecolot on primo and on the work Mac. Measure SC-006 with the helper cold (`launchctl kill TERM gui/$UID/com.kenscott.get-clear.helper` first): `time reminders lists` under 0.5 s. Record results in `research.md` → `## Spike results`.

**Checkpoint**: US1 works from a locally built app; nothing is packaged yet.

---

## Phase 4: User Story 3 — updates install themselves (P1)

**Goal**: `get-clear update` swaps in a verified, notarized app with no window and no password; the hint keys off the app's version.

**Independent Test**: install vN, publish vN+1 to a test tag, `get-clear update` → no window, `get-clear --version` = N+1, no new prompts. Repeat with a tampered zip → rejected, vN works.

- [X] T033 [P] [US3] Create `Sources/GetClearKit/UpdatePlan.swift`: `InstalledApp`, `UpdatePlan`, and `decide(installed:latest:appAsset:pkgAsset:)` per data-model. Spec `Tests/GetClearKitTests/UpdatePlanSpec.swift`: one `@Test` per outcome (`notInstalledAsApp`, `upToDate`, `selfUpdate`, `pkgFallback` for not-writable, `pkgFallback` for no zip asset, an older "latest" → `upToDate`).
- [X] T034 [US3] Update `Sources/GetClearKit/UpdateChecker.swift`: `installedVersion()` reads `CFBundleShortVersionString` from the containing `Get Clear.app` (via `AccessRoute`) instead of `pkgutil`; `spawnBackgroundCheckIfNeeded()` and `hint()` run only on the `.helper` route; the cached release carries both asset URLs (`Get-Clear.zip`, `get-clear.pkg`). Remove `packageID`/`binaryPath` if unused. Update `Tests/GetClearKitTests/UpdateCheckerSpec.swift` for the pure parts (version from a plist dictionary, asset selection from a releases JSON fixture).
- [X] T035 [US3] Create `Sources/GetClear/SelfUpdater.swift` (boundary): download `Get-Clear.zip` to a staging dir that is a sibling of the installed app; `ditto -x -k`; `SecStaticCodeCreateWithPath` + `SecStaticCodeCheckValidity` (`kSecCSCheckAllArchitectures | kSecCSStrictValidate`) against research R8's requirement string; check the staged version is newer; `renamex_np(staged, installed, RENAME_SWAP)`; `launchctl kickstart -k gui/<uid>/com.kenscott.get-clear.helper`; delete the swapped-out bundle. Staging removed on every exit path (`defer`). Progress lines to stderr per `contracts/cli-update.md`.
- [X] T036 [US3] Update `Sources/GetClear/UpdateCommand.swift`: build `InstalledApp` at the boundary (`Bundle(url:)`, `access(W_OK)` on the app's parent), call `UpdatePlan.decide`, and act: `.notInstalledAsApp` and `.upToDate` print the existing messages unchanged; `.selfUpdate` → `SelfUpdater`; `.pkgFallback` → the contract's fallback line, then today's PKG download-and-open flow. Verification and download failures print the contract's errors and exit 1.
- [ ] T037 [US3] Acceptance (quickstart §2 US3) with two locally built versions on primo: self-update succeeds with no window; a zip re-signed ad hoc is rejected and the old app still runs; a zip from a different identifier is rejected; `chmod a-w` the app's parent → fallback message (restore after). Confirm the hint disappears after the update (FR-015) and no reminders prompt reappears (FR-020).

**Checkpoint**: self-update works end to end against local artifacts.

---

## Phase 5: User Story 2 — install once, nothing else changes (P1)

**Goal**: The PKG installs the app and six symlinks, registers the helper, and upgrades 1.3.x cleanly; the release publishes both assets.

**Independent Test**: install the new PKG over 1.3.5; `which reminders` → `/usr/local/bin/reminders` → symlink into the app; each tool's `--version` and one command per tool match 1.3.5's stdout.

- [X] T038 [US2] (payload and PKG assembly live in a new `scripts/build-pkg`, shared by CI and local builds like `build-app`; the app is marked non-relocatable so Installer never "upgrades" a stray copy elsewhere) Update `.github/workflows/release.yml` `build` job: replace "Build all binaries" / "Sign binaries" / "Assemble payload" with `./scripts/build-app`; notarize and staple the app (`ditto -c -k --keepParent` → `notarytool submit --wait` → `stapler staple "Get Clear.app"` → re-zip as `Get-Clear.zip`); assemble the payload as `payload/Applications/Get Clear.app` plus `payload/usr/local/bin/<tool>` symlinks to `/Applications/Get Clear.app/Contents/Helpers/<tool>` for all six, the uninstaller at `payload/usr/local/share/get-clear/uninstall.sh`, and completions in `payload/usr/local/share/zsh/site-functions/` as today; upload **both** `get-clear.pkg` and `Get-Clear.zip` to the versioned and the rolling `latest` release; update the release notes text ("Installs Get Clear.app and its six commands").
- [X] T039 [US2] Update the `smoke-test` job in `.github/workflows/release.yml`: after install, assert each `/usr/local/bin/<tool>` is a symlink into the app, run `codesign --verify --deep --strict "/Applications/Get Clear.app"` and `spctl -a -vv "/Applications/Get Clear.app"`, then the existing `--version`/`help` checks.
- [X] T040 [US2] Update `pkg/scripts/postinstall`: before opening the guide, run `"/Applications/Get Clear.app/Contents/MacOS/Get Clear" register` in the console user's session (`launchctl asuser "$uid" sudo -u "$user" …`, user from `INSTALLER_USER` or `stat -f%Su /dev/console`), logging but not failing the install if it errors (the client self-heals, research R3). Idempotent (FR-013).
- [X] T041 [P] [US2] Check `pkg/distribution.xml` and `pkg/resources/welcome.html` / `conclusion.html` for wording about "five tools in /usr/local/bin"; update to describe the app and the one-time permission prompts naming Get Clear.
- [ ] T042 [US2] Pre-release run (plan step 5): bump to a pre-release version on the branch with `scripts/bump-version`, dispatch the release workflow against the branch to a test tag (not `latest`), and on a Mac with 1.3.5 installed: (a) install the new PKG directly and run the Independent Test plus a stdout diff against 1.3.5 for a fixed command set (SC-007); (b) on a second 1.3.5 install, let the **1.3.5 updater** (`get-clear update`) fetch and install it (FR-022, SC-009). Confirm `mail send` still reads its Keychain token with no prompt (research R11). Record results.

**Checkpoint**: the PKG and both release assets work, including the 1.3.x upgrade path.

---

## Phase 6: User Story 4 — uninstall removes everything (P2)

**Goal**: Nothing Get Clear installed remains after uninstall, except privacy decisions.

**Independent Test**: install, run a command so the helper is up, run the uninstaller; `launchctl print gui/$UID/com.kenscott.get-clear.helper` → not found; `which reminders` → nothing; no app, no receipt.

- [ ] T043 [US4] Update `scripts/uninstall`: run `"/Applications/Get Clear.app/Contents/MacOS/Get Clear" unregister` (as the user) before removal; remove `/Applications/Get Clear.app`, the six `/usr/local/bin` symlinks, completions, and the receipt (`pkgutil --forget com.kenscott.get-clear`); keep today's config and Keychain prompts; end by printing `tccutil reset All com.kenscott.get-clear` as the way to clear privacy decisions (FR-024). Also remove a 1.3.x layout (plain binaries) if found.
- [ ] T044 [US4] Acceptance (quickstart §2 US4) on primo, then reinstall.

---

## Phase 7: User Story 5 — development builds keep working (P3)

**Goal**: `swift build` binaries run from iTerm exactly as today.

- [ ] T045 [US5] Acceptance (quickstart §2 US5): with no app installed, `swift build` and run `.build/debug/reminders-bin lists` from iTerm. Expect today's behavior, prompts attributed to iTerm, and no added output. Covered at the unit level by T011's `.direct` cases.

---

## Phase 8: Polish, docs, and ship

- [ ] T046 [P] Add `ARCHITECTURE.md` decision-log entries: the helper model (app main executable as `SMAppService` agent, why: research R1–R2), the wire format (per-Lib request enums, opaque `Data` XPC method, typed tool errors), self-update (zip + `SecStaticCode` + `RENAME_SWAP`), the factory targets move, and `fetchCompleted` on `ReminderStore`. Add the new targets to the structure section.
- [ ] T047 [P] Update `README.md` install and permissions text: install from the PKG; the first command for each of Reminders, Calendars, Contacts, and Messages asks once for **Get Clear**; how to change it later in Privacy & Security; updates via `get-clear update` need no password.
- [ ] T048 [P] Update `CLAUDE.md` "Active Technologies" (spec 018 from planned to shipped) and the Build section (`./scripts/build-app`, `./scripts/build-icon`). Run `.specify/scripts/bash/update-agent-context.sh claude` and keep house style.
- [ ] T049 Run `swift build -c release` (zero new warnings), `./scripts/test` (report the count against T001's baseline), `./scripts/lint`.
- [ ] T050 Merge to `main` per the repo workflow, confirm CI green, bump the suite version with `scripts/bump-version`, dispatch the release workflow, and confirm both assets on the `vX.Y.Z` and `latest` releases. Confirm a 1.3.5 install's hint appears within the check interval. Then close #210 (last).

---

## Dependencies

```
T001 ─ T002 ─ T003 ─ T004 ─ T005 ─ T006 ─ T007        (spike: GATE)
                                            │
        ┌───────────────────────────────────┘
        ▼
T008 ─ T009        T010 ─ T011 [P]    T012 [P]   T013–T016 [P]      (Phase 2)
        │
        ├─ T017 ─ T018 ─ T019          (reminders wire; needs T008, T012, T013)
        ├─ T020 [P]                    (calendar wire; needs T014)
        ├─ T021 [P]                    (contacts wire; needs T015)
        ├─ T022 [P]                    (text wire; needs T016)
        └─ T023 ─ T024 ─ T025 ─ T026 ─ T027     (XPC + app + build-app)
                                         │
             T028 ─ T029 ─ T030 ─ T031 ─ T032  (factories, recap/setup, local acceptance)
                                         │
             T033 [P] ─ T034 ─ T035 ─ T036 ─ T037      (US3 self-update)
                                         │
             T038 ─ T039 ─ T040 ─ T041 [P] ─ T042      (US2 packaging + pre-release)
                                         │
             T043 ─ T044                               (US4 uninstall)
             T045                                      (US5)
             T046–T048 [P] ─ T049 ─ T050               (docs, verify, ship)
```

US3 comes before US2 because the pre-release run (T042) is the first real test of both, and FR-022 needs the new release to carry both assets.

## Parallel Execution Examples

**Phase 2** (after T008):
```
T010/T011  AccessRoute + spec
T012       ValueChange Codable
T013       reminders Codable
T014       calendar Codable
T015       contacts Codable
T016       text Codable
```

**Phase 3, wire pieces** (after Phase 2):
```
T018–T019  reminders (after T017)
T020       calendar
T021       contacts
T022       text
```

**Phase 8**:
```
T046  ARCHITECTURE.md
T047  README.md
T048  CLAUDE.md
```

## Implementation Strategy

- **The spike decides everything.** T002–T007 take an afternoon and need Ken at both Macs. A failure means rethinking R1, not patching.
- **MVP = Phases 1–3.** A locally built and signed app fixes #210 on Ken's own Macs, before any packaging work.
- **Phases 4–5 make it shippable.** Self-update and the PKG are tested together in the pre-release run (T042), which is the only end-to-end check of FR-022.
- **Ship (T050)** publishes the release the 1.3.x update notifier checks, so existing installs see the hint and update through their existing PKG flow.
- No handler signatures change, and no `main.swift` grows beyond dispatch. Every new source file ships with its spec in the same commit.
