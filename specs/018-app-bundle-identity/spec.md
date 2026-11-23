# Feature Specification: Get Clear App — Own Privacy Identity and Self-Update

**Feature Branch**: `018-app-bundle-identity`
**Created**: 2026-11-23
**Status**: Draft
**Issue**: #210
**Input**: User description: "Give the CLIs their own privacy identity so they work under any terminal. Ship all of Get Clear inside one signed app; the commands on PATH point into it; a helper inside the app owns access to Reminders, Calendar, Contacts, and Messages. First install is the PKG; every update after that replaces the app in place with no installer and no password."

## Background

Every Get Clear command that touches Reminders, Calendar, Contacts, or Messages asks macOS for permission. macOS attributes that request to the terminal app the command was run from, not to the command. Terminal.app and iTerm declare the privacy descriptions macOS requires, so the request is shown and can be granted. A terminal that declares none (Tecolot, `com.tirania.Tecolot`) has every request denied silently: no prompt appears, the terminal never shows up under Privacy & Security, and there is nothing the user can grant. `reminders lists` prints `Error: Reminders access denied` and there is no recovery.

Get Clear needs its own identity in macOS privacy settings — one that is the same no matter which terminal, script, or agent runs the command.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Works under any terminal (Priority: P1)

The user opens a terminal that Get Clear has never run under — one that declares no privacy descriptions. They run `reminders lists`. The first time, macOS asks whether **Get Clear** may access Reminders. They allow it. The lists print. From then on, every command that reads or writes reminders works from that terminal, from any other terminal, and from Claude, without asking again.

**Why this priority**: This is the defect. Without it, the suite is unusable under any terminal that hasn't declared privacy descriptions, and the user has no workaround.

**Independent Test**: On a Mac with Get Clear installed, run `reminders lists` from a terminal that declares no privacy descriptions. Confirm a permission prompt naming Get Clear appears, and after allowing it the lists print. Repeat from a second terminal; confirm no prompt and the lists print.

**Acceptance Scenarios**:

1. **Given** Get Clear has never been granted Reminders access, **When** the user runs a reminders command from any terminal, **Then** macOS shows one prompt naming Get Clear, and on approval the command completes.
2. **Given** Get Clear has Reminders access, **When** the user runs a reminders command from a different terminal, **Then** no prompt appears and the command completes.
3. **Given** the user denied the prompt, **When** they run a reminders command, **Then** the command fails with a message naming the permission, naming Get Clear as the app to enable in Privacy & Security → Reminders, and exits non-zero.
4. **Given** the same scenarios for Calendars, Contacts, and Automation → Messages, **Then** each behaves identically to Reminders.
5. **Given** Get Clear is listed under Privacy & Security, **When** the user looks at the entry, **Then** it reads "Get Clear" with the Get Clear icon — not a terminal name and not a bare command name.

---

### User Story 2 — Install once, nothing else changes (Priority: P1)

The user installs Get Clear from the PKG. After installation, the commands they already know — `reminders`, `calendar`, `contacts`, `mail`, `text`, `get-clear` — are on PATH and behave exactly as before: same arguments, same output, same speed. A user upgrading from a previous version notices nothing except that the commands now work under every terminal.

**Why this priority**: The fix must not cost the user anything. Commands, output, and scripts that depend on them must be unaffected.

**Independent Test**: Install the PKG over a 1.3.x installation. Run each tool's `--version` and one representative command per tool from a new terminal. Confirm output is identical in content to 1.3.x and the commands are found on PATH.

**Acceptance Scenarios**:

1. **Given** a Mac with no Get Clear installed, **When** the user installs the PKG, **Then** all six commands are on PATH and respond to `--version`.
2. **Given** a Mac with Get Clear 1.3.x installed from the PKG, **When** the user installs the new PKG, **Then** the old standalone commands are replaced, all six commands are on PATH, and no old copy is left behind.
3. **Given** any command, **When** it runs after the change, **Then** its stdout is byte-identical to the same command before the change, given the same data.
4. **Given** output is piped, **When** a command runs, **Then** stdout carries only command output, as before.
5. **Given** a 1.3.x user sees the update hint, **When** they run `get-clear update`, **Then** the update completes using the 1.3.x update path (PKG + Installer) and leaves them on the new layout.

---

### User Story 3 — Updates install themselves (Priority: P1)

A new version ships. The next command the user runs shows the existing one-line hint on stderr. They run `get-clear update`. It says what it's doing, downloads the new version, confirms it is genuinely signed by the Get Clear developer, replaces the installed app, and finishes. No Installer window, no password, nothing to click. Permissions the user already granted still apply.

**Why this priority**: The previous update flow ends in Installer.app and a password every time. Moving to an app is the opportunity to make every update after the first one a single command with no interruption.

**Independent Test**: With an older version installed and a newer release available, run `get-clear update`. Confirm no window opens and no password is requested, `get-clear --version` reports the new version, and a reminders command runs without a permission prompt.

**Acceptance Scenarios**:

1. **Given** a newer version is available, **When** the user runs `get-clear update`, **Then** it prints progress, replaces the app, prints the new version, and exits 0 — with no window and no password prompt.
2. **Given** the downloaded update is not signed by the Get Clear developer, or its signature does not verify, **When** `get-clear update` runs, **Then** it refuses to install, leaves the current version untouched, prints why, and exits non-zero.
3. **Given** the download fails or is interrupted, **When** `get-clear update` runs, **Then** the installed version is untouched and still works, and the command prints a clear error and exits non-zero.
4. **Given** permissions were granted before the update, **When** the update completes, **Then** every command runs without re-prompting.
5. **Given** a command is running while the update replaces the app, **When** the update completes, **Then** the running command either finishes on the old version or fails cleanly with a message — never a partial or corrupted result.
6. **Given** the user cannot write to the location the app is installed in, **When** they run `get-clear update`, **Then** it falls back to downloading the PKG and opening it in Installer (the existing flow), saying so before it does.
7. **Given** the user is already on the latest version, **When** they run `get-clear update`, **Then** it prints "Already on the latest version (X.Y.Z)." and exits 0, as today.
8. **Given** an update just completed, **When** the user runs any command, **Then** the update hint no longer appears.

---

### User Story 4 — Install without the PKG (Priority: P2)

A developer sets up a new machine with the curl one-liner. It installs the same app and puts the same six commands on PATH, without an Installer window. The commands get the same privacy identity as a PKG install, and `get-clear update` works the same way.

**Why this priority**: The curl installer is the scripted-setup path (dotfiles, new machines). It should not be a second-class install that still has the terminal-attribution defect.

**Independent Test**: On a Mac with no Get Clear installed, run the curl installer. Confirm the six commands are on PATH, a reminders command from a terminal that declares no privacy descriptions prompts for Get Clear, and `get-clear update` against a newer release self-updates.

**Acceptance Scenarios**:

1. **Given** no Get Clear installed, **When** the curl installer runs, **Then** the app is installed in the user's own Applications folder and the six commands are on PATH without requiring a password.
2. **Given** an existing curl install of the standalone binaries, **When** the curl installer runs, **Then** the standalone binaries are replaced by commands that point into the app.
3. **Given** a curl install, **When** a newer version ships, **Then** the update hint appears and `get-clear update` self-updates exactly as for a PKG install.
4. **Given** the curl installer is run twice, **Then** the second run completes without error and leaves one working installation.

---

### User Story 5 — Uninstall removes everything (Priority: P2)

The user runs the uninstaller. It removes the app, the commands on PATH, the background helper registration, and the PKG receipt. It offers to remove config and Keychain credentials, as today. Afterward nothing Get Clear installed remains, except the user's privacy decisions, which the uninstaller tells them how to reset.

**Why this priority**: The app adds new things to the system (an app, a background helper). Each must be removable.

**Independent Test**: Install via PKG, run a command so the helper is running, run the uninstaller. Confirm the app is gone, the commands are gone, no Get Clear helper is running or registered, and the receipt is gone.

**Acceptance Scenarios**:

1. **Given** a PKG or curl installation with the helper running, **When** the uninstaller runs, **Then** the helper is stopped and unregistered, and the app and all six commands are removed.
2. **Given** the uninstaller has run, **When** the user runs `reminders`, **Then** the shell reports the command is not found.
3. **Given** the uninstaller has run, **Then** it prints how to clear Get Clear's privacy decisions, since only the user can reset those.

---

### User Story 6 — Development builds keep working (Priority: P3)

A developer builds the suite locally and runs a freshly built command from iTerm or Terminal.app. It works as it does today, without the app installed, without code signing, and without re-granting permissions after every rebuild.

**Why this priority**: The development loop must not get slower. It does not need the fix itself — development happens in terminals that already work.

**Independent Test**: On a machine with no Get Clear app installed, build locally and run a reminders command from iTerm. Confirm it works and prompts on behalf of iTerm, as today.

**Acceptance Scenarios**:

1. **Given** no Get Clear helper is available, **When** a locally built command runs, **Then** it accesses Reminders, Calendar, Contacts, and Messages directly, under the terminal's identity, as today.
2. **Given** a locally built command runs with no helper available, **Then** no hint, warning, or extra output appears.

---

### Edge Cases

- **The helper isn't running when a command needs it.** The command starts it and proceeds. The user never has to start, stop, or know about the helper.
- **The helper crashes mid-command.** The command fails with a clear message and exits non-zero. The next command starts a fresh helper.
- **The helper and the commands are different versions.** Cannot happen after an install or update because they ship and are replaced together. If it occurs anyway (e.g., a helper from the previous version is still running right after an update), the command detects the mismatch, uses a helper of its own version, and completes.
- **Two commands run at once** (e.g., Claude running several in parallel). Both complete correctly; neither waits on the other longer than the underlying store does today.
- **The user moves or renames the app.** Commands fail with a message saying the Get Clear app was not found where it was installed and how to fix it (re-run the installer), and exit non-zero.
- **Both a PKG install and a curl install exist.** The installer that runs second removes or replaces the first's commands, so exactly one set is on PATH.
- **The user had granted access to the terminal, not Get Clear.** Existing grants to iTerm or Terminal.app do not carry over. The first command for each store prompts once for Get Clear.
- **Permission denied for one store only.** Only commands needing that store fail; the others work.
- **`text` sends via Messages.** The Automation prompt names Get Clear as the app controlling Messages.
- **`get-clear update` is run by a process with no terminal** (e.g., Claude). It completes without needing any interactive input when self-update applies; when it must fall back to the PKG, it says so and that a password will be required.
- **Downloaded update with a valid signature from a different developer.** Rejected, same as an invalid signature.
- **Older update hint after the switch.** A 1.3.x install's update hint and `get-clear update` must still find and install the new release.
- **macOS version.** The supported macOS range does not change from what 1.3.x supports.

## Requirements *(mandatory)*

### Functional Requirements

**Identity and access**

- **FR-001**: Get Clear MUST have a single privacy identity, named "Get Clear", that is the same regardless of which terminal, script, or agent runs a command.
- **FR-002**: Every request for Reminders, Calendars, Contacts, or Automation → Messages MUST be made under the Get Clear identity, never under the calling terminal's.
- **FR-003**: Get Clear MUST request exactly these four permissions and no others: Reminders (full access), Calendars (full access), Contacts, Automation → Messages. Each MUST carry a usage description that says, in plain language, what Get Clear does with that access.
- **FR-004**: Each permission MUST be requested only when a command first needs it — not all at install or at launch.
- **FR-005**: When a permission is denied, the command MUST fail on stderr with a message naming the permission and pointing to Privacy & Security → [that permission] → Get Clear, and exit non-zero.
- **FR-006**: The helper that holds this identity MUST start on demand when a command needs it and MUST NOT require the user to start, stop, enable, or configure it.
- **FR-007**: The helper MUST NOT run any work of its own: no polling, no background sync, no network access. It performs only what a command asks of it, and MAY stop itself when idle.
- **FR-008**: Only Get Clear's own commands, signed by the same developer, may ask the helper to do anything.

**Packaging and install**

- **FR-009**: Everything Get Clear installs — the six commands and the helper — MUST live inside one signed, notarized app named "Get Clear".
- **FR-010**: The six commands MUST be on PATH under their existing names, each pointing into the app.
- **FR-011**: The PKG MUST install the app and the PATH commands, register the helper, and remove standalone commands left by 1.3.x.
- **FR-012**: The curl installer MUST install the same app into the user's own Applications folder, put the six commands on PATH without a password, and remove standalone binaries left by earlier curl installs.
- **FR-013**: Both installers MUST be idempotent.
- **FR-014**: Command arguments, stdout, stderr wording, and exit codes MUST be unchanged by this feature, except for the new permission-denied wording in FR-005.

**Updates**

- **FR-015**: The existing update hint MUST continue to appear on stderr when a newer version is available — for PKG installs and curl installs alike — and MUST stop appearing once the update is installed.
- **FR-016**: `get-clear update` MUST replace the installed app with the new version with no window and no password, when the user can write to the app's location.
- **FR-017**: Before replacing anything, `get-clear update` MUST verify that the download is signed by the Get Clear developer, is notarized, and is intact. If any check fails, it MUST leave the installed version untouched, print why, and exit non-zero.
- **FR-018**: The replacement MUST be all-or-nothing: at every moment either the old version or the new version is fully installed and working.
- **FR-019**: After an update, a helper from the previous version MUST NOT serve commands from the new version.
- **FR-020**: Permissions granted before an update MUST still apply after it.
- **FR-021**: When the user cannot write to the app's location, `get-clear update` MUST fall back to the PKG + Installer flow, saying so and that a password will be required.
- **FR-022**: A 1.3.x installation's existing update path MUST be able to install this release.

**Uninstall**

- **FR-023**: The uninstaller MUST stop and unregister the helper and remove the app, the PATH commands, and the PKG receipt. Config and credential removal behaves as today.
- **FR-024**: The uninstaller MUST tell the user how to reset Get Clear's privacy decisions.

**Development**

- **FR-025**: When no Get Clear helper is available, commands MUST access the stores directly, as they do today, with no added output.

### Key Entities

- **Get Clear app**: The one installed thing. Holds the six commands and the helper. Carries the Get Clear name, icon, developer signature, and the four usage descriptions. Replaced as a unit on update.
- **Helper**: The part of the app that holds the Get Clear privacy identity and performs store access on behalf of commands. Started on demand; no work of its own.
- **PATH commands**: The six names the user types. Each points into the app; they never contain code of their own and never need to change on update.
- **Permission**: One of the four privacy grants, owned by the Get Clear identity, decided by the user once per Mac.
- **Release**: A version published on GitHub, available both as a PKG (first install, fallback) and as the signed app alone (self-update, curl install).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: From a terminal that declares no privacy descriptions, every one of the six commands completes its normal task after at most one permission prompt per store.
- **SC-002**: After permissions are granted once, zero further prompts appear across any number of terminals, commands, and updates.
- **SC-003**: Privacy & Security lists exactly one Get Clear entry per permission, named "Get Clear".
- **SC-004**: `get-clear update` from an older version to a newer one completes with zero windows, zero passwords, and zero clicks when the app location is writable.
- **SC-005**: A tampered or foreign-signed update is rejected 100% of the time, and the installed version still works afterward.
- **SC-006**: Commands that ran in under 0.5 s before this feature still run in under 0.5 s after it, measured on the same machine with the helper not yet running.
- **SC-007**: For the same data, every command's stdout is identical before and after this feature.
- **SC-008**: After uninstall, nothing Get Clear installed remains on disk or registered with the system, apart from the user's privacy decisions.
- **SC-009**: A Mac on 1.3.x reaches the new version through its existing update hint and `get-clear update` with no manual steps beyond the one password the 1.3.x flow already requires.

## Assumptions

- **The fix requires a separate process.** macOS attributes a permission request to the app that launched a command, so a command run from a terminal can't take on a different identity by itself, wherever it lives on disk. The helper exists for this reason. Moving the commands into the app is for packaging and updates, not permissions.
- **Mail needs no new permission.** `mail` sends through Fastmail's JMAP API, not Mail.app. It uses Contacts only to resolve names, which is covered by the Contacts permission.
- **Sparkle and similar update frameworks are out of scope.** The existing update hint plus `get-clear update` already provide discovery and installation; self-update replaces only the installation step.
- **Admin accounts can write to /Applications by default**, so self-update without a password applies to the PKG install for most users. Non-admin users fall back to the PKG flow (FR-021).
- **The PKG is still required for the first install** of a PKG-based setup, because putting commands in `/usr/local/bin` needs administrator rights once.
- **Signing and notarization use the existing Developer ID Application and Installer certificates** and the existing CI release pipeline.
- **Grants made to terminals are not migrated.** macOS offers no way to transfer them; one prompt per store is the accepted one-time cost.
- **Development builds are not expected to have the Get Clear identity.** They keep today's terminal-attributed behavior (FR-025).
