# Feature Specification: Shell Completions

**Feature Branch**: `main` (commits e93e671, 4b51681, 2026-03-14; get-clear #4)
**Created**: 2026-03-14
**Status**: Shipped (2026-03-14; closed get-clear #4; Phase 3 ✓ in going-live.md)
**Input**: The five Get Clear tools had no tab completion. Typing `reminders list ` required the user to know list names from memory. Completing command names required knowing the vocabulary. For a suite used interactively in the terminal, missing completions are a significant friction point — especially for a Claude-first tool where the human interaction path should be as smooth as the AI path.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Commands complete on first tab (Priority: P1)

The user types `reminders ` and presses Tab. A list of commands appears: `open`, `lists`, `list`, `find`, `show`, `add`, `change`, `rename`, `done`, `remove`. The user types `l` and presses Tab — `list` and `lists` narrow the options. This works identically for all five tools.

**Why this priority**: Command discovery is the primary value of shell completions. Without it, new users must consult the help text for every operation. With it, the vocabulary is self-documenting.

**Independent Test**: In a fresh zsh session, type `reminders ` and press Tab twice. Verify all commands appear with descriptions. Type `calendar ` Tab — verify calendar commands appear.

**Acceptance Scenarios**:

1. **Given** the user types `<tool> ` and presses Tab, **When** zsh loads the completion, **Then** all commands for that tool appear with short descriptions.
2. **Given** a partial command (e.g., `reminders li`), **When** Tab is pressed, **Then** matching commands narrow the list.
3. **Given** the same Tab behavior across all five tools, **When** the user switches between tools, **Then** the completion style is consistent — same format, same descriptions pattern.

---

### User Story 2 — Dynamic list and group names complete (Priority: P1)

The user types `reminders list ` and presses Tab. The completion fetches the actual reminder lists from the user's reminders database and offers them as completions: `Ibotta`, `Personal`, `Trinity Council`. The user types `reminders list I` Tab and `Ibotta` fills in. The same works for `contacts list <group>` (groups from contacts) and `calendar <subset>` (configured subset names).

**Why this priority**: Static command completions save a keystroke. Dynamic completions save a lookup — the user doesn't need to remember list names, group names, or subset names. This is the completion feature that matters most for daily use.

**Independent Test**: Run `reminders list ` Tab in a zsh session. Verify the names match the output of `reminders lists`. Add a new reminder list in Reminders.app, wait for the database to update, and verify the new list appears in completions.

**Acceptance Scenarios**:

1. **Given** `reminders list ` Tab, **When** the completion loads, **Then** it shows the actual reminder list names from the live database (via `reminders lists`).
2. **Given** `contacts list ` Tab, **When** the completion loads, **Then** it shows actual contact group names (via `contacts lists`).
3. **Given** `calendar ` Tab, **When** the completion loads, **Then** configured subset names appear (from the tool's config).
4. **Given** a completions result is fetched and the user's data changes (new list added), **When** Tab is pressed again, **Then** the updated list appears — completions are not cached.

---

### User Story 3 — PKG and curl installs both get completions (Priority: P1)

A user who installs via PKG has completions available automatically. A user who installs via the curl installer also gets completions — the script patches their `~/.zshrc` to include the completions directory in `$fpath` before `compinit`. Neither user needs to manually configure zsh.

**Why this priority**: Completions that require manual setup will not be used. They must be zero-config for both install paths.

**Independent Test**: Install via PKG on a clean machine. Open a new terminal and Tab-complete a `reminders` command — completions should work without any manual zsh configuration. Repeat with the curl installer.

**Acceptance Scenarios**:

1. **Given** a PKG install, **When** the user opens a new terminal, **Then** completions work without manual zsh configuration.
2. **Given** a curl install, **When** the install script completes, **Then** `~/.zshrc` contains an `fpath` entry pointing to the completions directory, placed before `compinit`.
3. **Given** an existing `~/.zshrc` with `compinit`, **When** the curl installer patches it, **Then** the `fpath` entry is inserted before the existing `compinit` call, not after.

---

### Edge Cases

**Dynamic completion output includes ANSI codes**
The completion scripts call `reminders lists` and strip ANSI codes via `sed` before presenting them. Without the strip, the list names would include escape sequences that break completion matching. The strip is: `sed 's/\x1b\[[0-9;]*m//g'`.

**zsh only**
Completions are zsh-only. bash and fish were considered and rejected — macOS default since Catalina is zsh, and the audience (developers who use the terminal) overwhelmingly uses zsh or fish. Fish completions have a different format entirely. Zsh completions are the right call for now; fish can be added if demand materializes.

**`fpath` must precede `compinit`**
zsh loads completion functions at `compinit` time. If the completions directory is added to `fpath` after `compinit`, the completions are not registered for the current session. The PKG installs to `/usr/local/share/zsh/site-functions/`, which is in the default zsh `fpath`. The curl installer installs to `~/.local/share/zsh/site-functions/` and patches `fpath` in `~/.zshrc` before any `compinit` line.

**Completion for `show`/`change`/`done`/`remove`**
These commands require exact title matching. The completions for these commands fetch live reminder titles by running `reminders list`, stripping ANSI codes, stripping the bullet and metadata, and presenting the raw titles. This is the same ANSI-stripping pipeline used when Claude needs to extract exact titles.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: zsh completion files for all five tools MUST exist in `get-clear/completions/` as `_reminders`, `_calendar`, `_contacts`, `_mail`, `_sms`.
- **FR-002**: Each completion file MUST use `#compdef <tool>` to register with zsh.
- **FR-003**: All commands for each tool MUST be listed with short descriptions in the completions file.
- **FR-004**: Second-argument completions for `reminders list`, `reminders show`, `reminders change`, `reminders done`, `reminders remove` MUST be dynamic — fetched at completion time from the live reminders database via `reminders lists` or `reminders list`.
- **FR-005**: Dynamic completions MUST strip ANSI codes from command output before presenting to zsh.
- **FR-006**: The PKG installer MUST bundle completion files to `/usr/local/share/zsh/site-functions/`, which is in the default macOS zsh `fpath`.
- **FR-007**: The curl installer MUST add `~/.local/share/zsh/site-functions/` to `fpath` in `~/.zshrc` before any `compinit` line.
- **FR-008**: Completions MUST work with no additional user configuration beyond the install step.

### Key Entities

- **`completions/_reminders`** through **`completions/_sms`**: zsh completion functions, one per tool, in `get-clear/completions/`.
- **`fpath` patch**: Line added to `~/.zshrc` by curl installer to include completions directory.
- **ANSI strip pipeline**: `sed 's/\x1b\[[0-9;]*m//g'` applied to dynamic completion output.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Pressing Tab after `reminders ` shows all commands with descriptions — no manual `compdef` invocation required.
- **SC-002**: Pressing Tab after `reminders list ` shows live reminder list names — no hardcoded list of names in the completion file.
- **SC-003**: Completions work immediately after PKG install in a new terminal session.
- **SC-004**: Completions work immediately after curl install once `~/.zshrc` is sourced.
- **SC-005**: No ANSI codes appear in completion menu items — the strip pipeline is correct.

## Design Notes

**Completions call live binaries.** The dynamic completion functions call `reminders lists`, `reminders list`, `contacts lists` etc. at completion time. This means the binaries must be installed and the user must have granted the relevant permissions (Reminders, Contacts) before completions work for those arguments. The failure mode is graceful — if the binary isn't found or permissions aren't granted, the completion returns nothing rather than erroring.

**Command-level completions are the floor, not the ceiling.** Completing command names is the minimum. The most valuable completions are the dynamic ones — list names, group names — because those are the data the user can't remember. Future completions could include reminder titles for `done`/`remove`, but the title space is large and changes frequently; this is left for future work.

**zsh site-functions directory.** `/usr/local/share/zsh/site-functions/` is in the default macOS zsh `fpath` on all modern macOS versions. The PKG installer uses this location to avoid needing any `fpath` patching for PKG users. The curl installer uses `~/.local/share/zsh/site-functions/` (user-local, no admin required) and patches `fpath` accordingly.

## Assumptions

- The user's shell is zsh (macOS default since Catalina 10.15).
- Dynamic completions tolerate a ~100ms latency from the binary call — this is acceptable for interactive use.
- The completion files do not need to be updated when new commands are added to the tools; this is a manual maintenance step.
