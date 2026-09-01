# Feature Specification: Private Reminders Metadata via ReminderKit

**Feature Branch**: `014-private-reminders-metadata`
**Created**: 2026-08-31
**Status**: Draft
**Input**: User description: "Private Reminders metadata via ReminderKit — a consent-gated, default-safe capability for Apple Reminders features EventKit cannot reach. Sections first (list sections, create/rename/remove a section, assign a reminder to a section); designed to later hold tags, subtasks, urgent state, Early Reminders. A clean install is inert until the user runs a deliberate registration command; runtime inputs can only move toward safe, never toward on; a stale marker (OS major version or consent version changed) reverts to inert. First deliberate exception to the suite no-flags rule."

---

## Background

Apple Reminders has features that its public automation surface (EventKit) does not expose: **sections** within a list, real synced **tags**, **subtasks**, the real **flagged** state, **Early Reminders**, and the ability to **open a specific reminder** in Reminders.app. Get Clear's reminders tool is built entirely on EventKit and therefore cannot see or change any of them. A reminder filed into the "Research" section of a list shows up in `reminders list` with no indication of which section it is in, and there is no way to create a section or move a reminder into one without opening Reminders.app.

The only way to reach these features programmatically is through Apple's **private** `ReminderKit` framework and by reading the Reminders database directly. Both are unsupported by Apple. They change between macOS releases — the macOS 27 beta cycle alone renamed and removed private methods that a comparable tool depended on — and a break can range from a clean failure to a process crash at launch.

This feature adds that capability to the reminders tool **without** compromising the guarantee that the rest of the tool keeps working. It does so by making the private capability **inert on every clean install** and reachable only after a deliberate, informed opt-in that the user can point to, revoke, and that expires on its own when the conditions it was granted under change.

The capability's full intended surface is a fixed set: **sections, tags, subtasks, flagged state, Early Reminders, and opening a specific reminder** — plus the reads needed to display all of them. The first delivered slice is **sections**. The consent, safety, and boundary model is designed so the rest of that set are later additions to an existing capability rather than a new set of patterns. Everything outside that set — urgent state, rich-link and image attachments, shared-list assignment, list appearance, list groups, smart lists, templates, Groceries lists — is deliberately excluded (see Out of Scope).

---

## User Scenarios & Testing *(mandatory)*

The actors are the **person** running the reminders tool directly and **Claude** issuing commands on the person's behalf. Both are subject to the same rules — nothing about the private capability is reachable by Claude that is not reachable by the person, and vice versa.

### User Story 1 — A clean install is safe and stays that way (Priority: P1)

Someone installs Get Clear. They have never opted into private features. Every ordinary reminders command works. Every command that would need private access refuses with an explanation and a pointer to how to enable it — and in refusing, touches nothing unsupported: no private framework is loaded, the Reminders database is never opened.

**Why this priority**: This is the guarantee the whole feature is built to protect. If a clean install can be made to load private code — by any argument, environment variable, or state short of the deliberate opt-in — the safety model has failed. Everything else is gated behind this.

**Independent Test**: On a machine that has never registered private access, run the full ordinary command set (works) and each private command (refuses with a pointer). Confirm via process inspection that no private framework was loaded and the Reminders store file was never opened.

**Acceptance Scenarios**:

1. **Given** a clean install, **When** the user runs `reminders list`, **Then** it behaves exactly as it does today.
2. **Given** a clean install, **When** the user runs a command that needs private access (e.g. `reminders sections`), **Then** the tool exits non-zero with a message on stderr naming the private capability, stating it is off by default, and telling the user the command to enable it.
3. **Given** a clean install, **When** any private command is refused, **Then** no private framework is loaded into the process and the Reminders database file is not opened.
4. **Given** a clean install, **When** the user sets every environment variable and passes every argument the tool recognizes, **Then** there is still no combination that enables private access without the registration command.

---

### User Story 2 — Registering private access (Priority: P1)

The user wants section support. They run the registration command. The tool explains, in specific terms, what the private capability is, that it relies on unsupported Apple internals, that it can break on any macOS update, and how to turn it back off. It requires a typed confirmation — not a single keystroke. It walks the user through granting the system permission the read side needs. It checks whether the private capability actually works on this version of macOS and reports the result. Only then does it record that private access is enabled.

**Why this priority**: Registration is the only path from inert to enabled. It has to be deliberate enough that no one enables it by reflex, and informative enough that the compatibility check on the current OS is delivered as part of it.

**Independent Test**: On a clean install, run the registration command, complete every step, and confirm that afterward `reminders sections` works. Run it again and confirm it is idempotent — it detects the existing registration and does not re-prompt for consent.

**Acceptance Scenarios**:

1. **Given** a clean install, **When** the user runs the registration command and completes it, **Then** private commands work for subsequent invocations.
2. **Given** the registration command is running, **When** it asks for confirmation, **Then** it requires a specific typed phrase and treats anything else — including an empty line or "y" — as a decline, makes no change, and exits non-zero.
3. **Given** the registration command, **When** it reaches the compatibility check, **Then** it reports which private capabilities are available on the current macOS and warns clearly if any the feature needs are missing.
4. **Given** private access is already registered, **When** the user runs the registration command again, **Then** it reports the current state and does not repeat the consent prompt.
5. **Given** the registration disclosure text, **When** it is shown, **Then** it names the specific capabilities in scope, the specific risk (unsupported, may break on macOS updates), and the specific way to disable — not vague "advanced features" language.

---

### User Story 3 — Seeing and assigning sections (Priority: P1)

With private access registered, the user can list the sections in a reminder list, see which section each reminder is in, and move a reminder into a section or out of one.

**Why this priority**: This is the delivered value. Stories 1 and 2 are the safety envelope; this is the thing the user actually wanted.

**Independent Test**: In a list that has sections, run the sections listing (shows the sections), run the reminder listing (each reminder shows its section), assign an unsectioned reminder to a section (it moves), then clear its section (it becomes unsectioned). Confirm each result by re-reading.

**Acceptance Scenarios**:

1. **Given** a list with sections "Research" and "Drafts", **When** the user lists sections for that list, **Then** both section names are shown.
2. **Given** a list where some reminders are in sections, **When** the user lists the reminders, **Then** each reminder's section is shown and unsectioned reminders are clearly distinguished.
3. **Given** an unsectioned reminder and a section "Research" in its list, **When** the user assigns the reminder to "Research", **Then** re-reading the reminder shows it in "Research".
4. **Given** a reminder in a section, **When** the user clears its section, **Then** re-reading the reminder shows it unsectioned.
5. **Given** a section name that does not exist in the target list, **When** the user tries to assign a reminder to it, **Then** the tool fails with a message naming the available sections and makes no change.
6. **Given** the same section name exists in two different lists, **When** the user assigns a reminder, **Then** the section is resolved within the reminder's own list and the other list's section is never affected.

---

### User Story 4 — Creating, renaming, and removing sections (Priority: P2)

The user can create a new section in a list, rename an existing section, and remove a section. Removing a section does not delete the reminders in it — they become unsectioned.

**Why this priority**: Full lifecycle management, and required by the suite rule that every create ships with its remove. Lower than Story 3 because a user can get value from assignment and display against sections they made in Reminders.app, but a create without a remove cannot ship at all.

**Independent Test**: Create a section (appears in the listing), rename it (new name appears, old name gone), assign a reminder to it, remove the section (section gone, reminder now unsectioned). Confirm each by re-reading.

**Acceptance Scenarios**:

1. **Given** a list with no section named "Reading", **When** the user creates section "Reading" in that list, **Then** it appears in the sections listing for that list.
2. **Given** a list that already has a section named "Reading", **When** the user tries to create another "Reading" in the same list, **Then** the tool fails and makes no change.
3. **Given** a section "Research", **When** the user renames it to "Reading", **Then** the listing shows "Reading" and not "Research".
4. **Given** a rename target name that collides with another section in the same list, **When** the user renames, **Then** the tool fails and makes no change.
5. **Given** a section "Drafts" containing three reminders, **When** the user removes "Drafts", **Then** the section is gone and all three reminders still exist and are unsectioned.

---

### User Story 5 — Forcing safe mode for one run (Priority: P2)

Private access is registered, but a macOS update has destabilized the private capability and section commands are now failing badly. The user needs the rest of the reminders tool to keep working while they wait for a fix. They can force a single invocation into safe mode, and they can set an environment variable so every invocation in their shell session is safe, without un-registering.

**Why this priority**: The recovery path for the window between an OS breaking the private capability and Get Clear shipping a fix. Distinct from un-registering because it is immediate, reversible, and does not throw away the consent.

**Independent Test**: With private access registered, force-safe a single private command (it refuses cleanly, like a clean install would) while an un-forced ordinary command in the same state still runs normally. Confirm the force-safe path also loads no private framework.

**Acceptance Scenarios**:

1. **Given** private access is registered, **When** the user runs a private command with the force-safe override, **Then** it refuses exactly as it would on a clean install and loads no private code.
2. **Given** private access is registered, **When** the force-safe environment variable is set, **Then** every command in that session behaves as if private access were not registered.
3. **Given** any state, **When** the user provides a runtime input, **Then** there is no runtime input that turns private access **on** — runtime inputs can only force it off.
4. **Given** the force-safe override, **When** the user runs the reminders help output, **Then** the override is not listed there.

---

### User Story 6 — A registration expires when its conditions change (Priority: P2)

The user registered private access on macOS 26. They upgrade to macOS 27. The next time they run a private command, the tool tells them the registration no longer applies because the OS changed and asks them to register again — which re-runs the compatibility check against the new OS. The same thing happens if a Get Clear update changes the private capability enough to invalidate prior consent.

**Why this priority**: A macOS major version boundary is exactly where the private capability's risk profile changes. Consent given under the old conditions should not silently carry forward, and re-registration is how the user finds out what still works on the new OS.

**Independent Test**: Register private access. Simulate an OS-major change and a consent-version bump independently. In each case, confirm the next private command reverts to the clean-install refusal with a message explaining the registration expired, and that re-running registration restores access.

**Acceptance Scenarios**:

1. **Given** private access registered under one OS major version, **When** the OS major version changes, **Then** the next private command refuses with a message stating the registration expired because the OS changed and pointing at re-registration.
2. **Given** an expired registration, **When** a private command refuses, **Then** no private framework is loaded — an expired registration is treated exactly like no registration.
3. **Given** an expired registration, **When** the user re-runs the registration command, **Then** it repeats the full flow including the compatibility check, and access is restored.
4. **Given** a Get Clear update that raises the consent version, **When** the user runs a private command, **Then** the prior registration is treated as expired.

---

### Edge Cases

- **The system permission for the read side is not granted** after registration (revoked later, or a different execution context): section **display** and **listing** fail with a message pointing at the permission; the tool does not crash and does not fall back to guessing.
- **The compatibility check itself fails or crashes** during registration: registration does not record an enabled state on the strength of a failed check; it reports that private features will not work on this OS and does not claim success.
- **A private write reports success but the change did not sync** (a known failure mode of the underlying APIs): the tool verifies each write by re-reading before reporting success, and reports a write that did not take as a failure, not a success.
- **A macOS update renames or removes a private method** the feature uses without crashing: the command fails with a specific message that the capability is unavailable on this macOS version — never a silent no-op that appears to succeed.
- **The reminder's list is inside a list group** (nested): section operations still resolve the reminder and its list correctly.
- **The person runs a private command via Claude in a non-Terminal context** where the system permission is scoped differently: the failure names the execution context that lacks access, not a generic permission error.
- **`reminders list` is run with private access registered but a section read fails**: the reminder list still renders; the section column degrades to absent for the affected list rather than failing the whole command (read-only commands never fail the user's primary request over a secondary enrichment).

---

## Requirements *(mandatory)*

### Functional Requirements — Safety model

- **FR-001**: A clean install MUST treat the private capability as inert: every command that requires private access MUST refuse, exit non-zero, and emit a message to stderr, without loading any private framework or opening the Reminders database.
- **FR-002**: The ONLY thing that moves the private capability from inert to enabled MUST be a persistent marker written by the registration command. No argument, environment variable, config value, or default may enable private access by any other route.
- **FR-003**: Runtime inputs (arguments, environment variables) MUST be able to force the private capability off for the current invocation or session, and MUST NOT be able to turn it on.
- **FR-004**: The refusal message for an unregistered private command MUST name the capability, state that it is off by default, and give the exact command to enable it.
- **FR-005**: When the private capability is enabled and a required underlying platform method is absent on the current macOS, the tool MUST fail the affected command with a specific "unavailable on this macOS" message. It MUST NOT silently do nothing and report success.
- **FR-006**: Every private write MUST be verified by re-reading the affected record before the tool reports success. A write that did not take effect MUST be reported as a failure.

### Functional Requirements — Registration

- **FR-007**: The tool MUST provide a registration command that enables the private capability. Working surface: `reminders setup private`.
- **FR-008**: The registration command MUST display a disclosure that names the specific capabilities in scope, states that they rely on unsupported Apple internals and may break on any macOS update, and states how to disable them. Vague framing ("advanced features", "help us improve") MUST NOT satisfy this.
- **FR-009**: The registration command MUST require a specific typed confirmation phrase. A single keystroke, an empty line, or "y" MUST be treated as a decline that makes no change and exits non-zero.
- **FR-010**: The registration command MUST guide the user through granting the system permission the read side requires, and MUST verify that permission is effective before recording success.
- **FR-011**: The registration command MUST run a compatibility check for the private capabilities the feature needs on the current macOS and report the result to the user.
- **FR-012**: If the compatibility check fails or cannot complete, the registration command MUST NOT record an enabled state that claims the capability works; it MUST report that private features will not function on this OS.
- **FR-013**: The registration marker MUST record the macOS major version and a consent version it was created under.
- **FR-014**: The registration command MUST be idempotent: run again while already registered, it reports current state and does not repeat the consent prompt. (Consistent with the suite `setup` rule.)
- **FR-015**: The tool MUST provide a command to remove the registration marker (disable private access). Working surface: `reminders setup private off`. This command MUST NOT require loading any private code.
- **FR-016**: `reminders setup` with no arguments MUST report whether private access is currently enabled, disabled, or expired.

### Functional Requirements — Expiry

- **FR-017**: On every run, if the recorded macOS major version does not match the current one, OR the recorded consent version is below the version the current build requires, the private capability MUST be treated as inert (identical to no registration) until the user re-registers.
- **FR-018**: The refusal message for an expired registration MUST state why it expired (OS changed, or Get Clear updated) and point at re-registration.

### Functional Requirements — Sections

- **FR-019**: The tool MUST list the sections of a reminder list by name.
- **FR-020**: The tool MUST show, in reminder listings, which section each reminder belongs to, and MUST distinguish unsectioned reminders.
- **FR-021**: The tool MUST assign a reminder to a section within that reminder's own list, and MUST clear a reminder's section (make it unsectioned). Section assignment is an attribute change on the reminder, expressed through the existing `change` vocabulary (`change … section "Research"`, `change … section none`).
- **FR-022**: Section resolution MUST be scoped to the reminder's own list. A section of the same name in another list MUST never be affected.
- **FR-023**: Assigning to a section that does not exist in the target list MUST fail with a message listing the available sections and make no change.
- **FR-024**: The tool MUST create a section in a named list, refusing a name that already exists in that list.
- **FR-025**: The tool MUST rename a section, refusing a new name that collides with another section in the same list.
- **FR-026**: The tool MUST remove a section. Reminders in a removed section MUST survive and become unsectioned.
- **FR-027**: Section create and section remove MUST ship in the same release (suite rule: add and remove ship together).

### Functional Requirements — Reads that do not require private writes

- **FR-028**: Listing sections and showing a reminder's section MUST NOT require the private write framework. They require only the read side and its system permission. (This keeps display working even if the write capability is unavailable on a given macOS.)
- **FR-029**: The read side MUST open the Reminders database read-only and MUST NOT write to it under any circumstance.

### Functional Requirements — Suite documents

- **FR-030**: `design.md` and the suite constitution MUST be amended in the same release to describe (a) the "failsafe, not affordance" category of flag that the force-safe override belongs to and why it is permitted where feature flags are not, and (b) the consent-gated, default-inert capability model.
- **FR-031**: The force-safe override MUST be absent from `--help` / `usage()` output, consistent with the suite rule for internal commands.

### Key Entities

- **Private capability state**: The effective mode for an invocation — **inert** (default; nothing private loads), **enabled** (a valid registration marker is present and current), or **forced-safe** (a runtime input has overridden to inert for this run/session). Only a valid, current marker yields *enabled*.
- **Registration marker**: The persisted record that the user opted into private access. Carries the macOS major version and the consent version it was made under. Considered **expired** when either no longer matches the current environment. Its presence-and-currency is the sole enabler of private access.
- **Section**: A named subdivision within a single reminder list. Has a display name and a stable identity. Belongs to exactly one list. A reminder belongs to zero or one section within its own list. Renaming changes the display name, not the identity. Removing a section does not remove its reminders.
- **Capability probe result**: The outcome of checking, at runtime, whether the private platform methods the feature depends on are present. Either "available" or a specific unavailability naming what is missing. Consulted during registration and before each private operation.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a clean install, there is no sequence of arguments, environment variables, or config edits — short of running the registration command — that causes any private framework to load or the Reminders database to be opened. Verified by process/file-access inspection across the full command surface.
- **SC-002**: After completing registration, a user can list a list's sections, see each reminder's section, and move a reminder between sections — each confirmed by re-reading — in under two minutes.
- **SC-003**: When a required private method is missing on the running macOS, 100% of affected commands fail with a specific "unavailable on this macOS" message and 0% report a false success.
- **SC-004**: Every private write is followed by a verifying read; a write that does not take effect is reported as a failure in 100% of cases.
- **SC-005**: After a simulated macOS major-version change, the next private command reverts to the clean-install refusal with an expiry explanation, with no private code loaded — verified by inspection.
- **SC-006**: Removing a section never destroys a reminder: after removing a section containing N reminders, all N still exist and are unsectioned.
- **SC-007**: The reminders tool's ordinary (EventKit-only) commands are byte-for-byte unchanged in output for a user who never registers private access.

---

## Assumptions

- The read side (database) and the write side (private framework) are separate concerns with different failure modes and different permission requirements; the feature treats them as one *capability* for consent purposes but does not require the write side to be usable in order for the read side to work.
- The macOS **major** version is the right expiry granularity. Finer-grained breakage within a major version is caught at operation time by the capability probe, not by expiring the registration on every point release.
- Sections are the first slice. Tags, subtasks, flagged state, Early Reminders, and open-a-specific-reminder are in the capability's intended surface but land as subsequent slices — they are the reason the consent and boundary model is built to generalize. Each is independently valuable and sections proves the whole model, so they ship as follow-on work rather than all in this cycle.
- The single suite config file (`~/.config/get-clear/…`, tracked separately) is where the registration marker lives. If that consolidation has not landed, the marker uses the reminders tool's existing config location with the same semantics.
- "Full Disk Access" (or its macOS-current equivalent) is the system permission the read side needs; the registration flow owns walking the user to granting it, consistent with the constitution's "tools handle what they can."

## Out of Scope

**Subsequent slices of this capability** (in the intended surface, not this feature): tags, subtasks, flagged state, Early Reminders, opening a specific reminder. Each lands as follow-on work against the capability this feature establishes.

**Deliberately excluded from the capability** (the consent model would support them; the decision is not to build them):

- Urgent state — macOS-version-gated, narrow.
- Rich-link URL attachments and image attachments — real Reminders features EventKit cannot reach, but add-only semantics and low task-management value.
- Shared-list assignment.
- Manual reminder reordering within a list.
- List appearance — exact color, icon/emblem, sidebar pinning.
- List groups (folders of lists).
- Smart lists — reading or writing filter definitions.
- Templates — reading, applying, or creating. Reading is only useful to then create a list from a template, a capability with no existing vocabulary in the tool; the whole path is niche, fragile, and not worth the consent overhead.
- Groceries lists and aisle auto-categorization — the highest break risk of any private Reminders feature.

**Also out:**

- Location-based alarms — a public EventKit feature, tracked separately in #191. Not private, not consent-gated.
- Any write to the Reminders SQLite store.
- A general-purpose "private mode" spanning other tools (calendar, contacts, mail, text). This feature is reminders-only; the constitution amendment describes the model so a future tool could adopt it, but nothing else does now.
- Telemetry on private-feature usage.
