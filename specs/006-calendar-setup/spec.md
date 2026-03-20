# Feature Specification: Calendar Setup Command

**Feature Branch**: `main` (commit f6c256d, 2026-03-15)
**Created**: 2026-03-15
**Status**: Shipped (2026-03-15; reused pattern for `get-clear setup` in 001-activity-log)
**Input**: calendar-cli required a `config.toml` to know which calendars to show by default. The config format was documented but no tool existed to create it interactively. Users had to know TOML syntax and find calendar names exactly. The `setup` command eliminates both requirements.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Guided first-time configuration (Priority: P1)

A user installs calendar-cli and runs `calendar setup`. The tool displays all available calendars as a numbered list, each with a colored dot matching the calendar's native macOS color. The user types a number or name to include it. After selecting, the tool writes `~/.config/calendar-cli/config.toml` and confirms what was saved. The user runs `calendar today` and it shows only the calendars they picked.

**Why this priority**: Without `setup`, the barrier to correct configuration is high — knowing TOML, knowing exact calendar names, knowing the config file path. With `setup`, the path from install to working tool is three keystrokes.

**Independent Test**: Delete `~/.config/calendar-cli/config.toml`. Run `calendar setup`. Verify: numbered list with color dots appears, selecting by number produces the correct entry in config.toml, and `calendar today` reflects only those calendars.

**Acceptance Scenarios**:

1. **Given** no config file exists, **When** the user runs `calendar setup`, **Then** a numbered list of all available calendars is shown, each with a colored dot.
2. **Given** the numbered list, **When** the user enters a number, **Then** the calendar at that number is selected and its name is written to config.toml.
3. **Given** the numbered list, **When** the user enters a calendar name (partial or full), **Then** the matching calendar is selected.
4. **Given** selections are confirmed, **When** setup completes, **Then** `~/.config/calendar-cli/config.toml` is written with the correct `[work]` subset entries.
5. **Given** an existing config file, **When** the user runs `calendar setup` again, **Then** it overwrites the previous config — setup is re-runnable.

---

### User Story 2 — Color dots aid recognition (Priority: P2)

The numbered list in `calendar setup` shows each calendar with a colored dot using ANSI true-color sequences matching the calendar's native macOS color. The user recognizes their calendars visually — the same orange dot they see in Calendar.app appears next to "Ibotta" in the terminal.

**Why this priority**: Calendar names alone may be ambiguous — "Personal" might appear twice across iCloud and local accounts. The color dot is additional disambiguation. It also makes the setup experience feel native rather than generic.

**Independent Test**: Run `calendar setup` in a terminal that supports true-color (iTerm2, Terminal.app on Ventura+). Verify each calendar's dot matches the color shown in Calendar.app for that calendar.

**Acceptance Scenarios**:

1. **Given** a calendar with a known macOS color (e.g., red), **When** it appears in the setup list, **Then** the dot is rendered in that color using ANSI true-color (`\x1b[38;2;R;G;Bm●`).
2. **Given** `NO_COLOR` is set or output is piped, **When** setup runs, **Then** the dot appears as a plain `●` without color.

---

### Edge Cases

**The pattern was reused for `get-clear setup`**
The interactive wizard pattern established by `calendar setup` was directly reused for `get-clear setup` (the recap calendar picker, spec 001). The numbered-list + color-dot + selection UX is now the standard interactive wizard pattern for the suite.

**setup is idempotent**
Running `calendar setup` a second time overwrites the existing config. There is no "you already have a config, are you sure?" prompt. The command is safe to run multiple times — this is the intended behavior.

**True-color vs 256-color vs no-color**
The color dots use ANSI true-color (24-bit RGB) sequences because `EKCalendar.cgColor` provides RGB values, not a color index. The implementation does not fall back to 256-color — true-color is universally supported by modern macOS terminal emulators (iTerm2, Apple Terminal since macOS 10.12). The dots are suppressed entirely (via `ANSI.enabled`) when NO_COLOR is set or output is piped.

**calendarDot() vs ANSI helpers**
`calendarDot()` is implemented in the get-clear binary (for `get-clear setup`) using `ANSI.enabled` from GetClearKit. The dot rendering is not in GetClearKit itself — it requires EventKit's `cgColor` property, which is an Apple framework dependency. GetClearKit is framework-free; the dot function lives in the binary layer.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `calendar setup` MUST display all calendars accessible to the user via EventKit, numbered starting at 1.
- **FR-002**: Each calendar MUST be displayed with a colored dot using ANSI true-color sequences derived from `EKCalendar.cgColor`. The dot MUST be suppressed (plain `●` or no dot) when `ANSI.enabled` is false.
- **FR-003**: The user MUST be able to select by number or by calendar name (case-insensitive, partial match acceptable).
- **FR-004**: On completion, `calendar setup` MUST write `~/.config/calendar-cli/config.toml` with the selected calendars in the appropriate subset (e.g., `[work]` section).
- **FR-005**: `calendar setup` MUST be idempotent — running it again overwrites the existing config without error.
- **FR-006**: The setup output MUST confirm which calendars were saved before exiting.

### Key Entities

- **`calendar setup`**: Interactive command. Reads calendars from EventKit, presents numbered list with color dots, prompts for selection, writes config.toml.
- **`config.toml`**: Located at `~/.config/calendar-cli/config.toml`. Contains named subsets (e.g., `[work]`, `[personal]`) with calendar name lists.
- **`calendarDot(_ color: CGColor) -> String`**: Renders a colored `●` using ANSI true-color from EventKit's CGColor. Returns plain `●` when ANSI is disabled.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user with no prior config can run `calendar setup`, select calendars, and immediately use `calendar today` — no manual config file editing required.
- **SC-002**: Color dots in setup output match the colors shown in macOS Calendar.app for the same calendars.
- **SC-003**: `calendar setup` followed by `calendar work today` shows only the calendars selected for the work subset.
- **SC-004**: Running `calendar setup` twice with different selections produces the second selection in config.toml — no stale state from the first run.

## Design Notes

**Interactive wizards are the exception, not the rule.** The Get Clear suite is Claude-first — most operations go through natural language. `setup` commands exist precisely because they are the one case where the user must browse a dynamic list (calendar or list names) that Claude can't enumerate without running the tool first. Setup is the bootstrapping step; everything else is conversational.

**The numbered list is the UX.** Requiring the user to type exact calendar names would be hostile — calendar names can be long, include special characters, or have duplicates across accounts. Numbered selection with optional name matching is the right balance of speed and discoverability.

**Pattern propagated to `get-clear setup`.** The same numbered-list-with-color-dot pattern was used for the `get-clear setup` recap calendar picker (spec 001). The pattern is now established — any future setup wizard in the suite should follow it.

## Assumptions

- EventKit provides `EKCalendar.cgColor` (a `CGColor`) for all calendars. The RGB components can be extracted and converted to ANSI true-color integers.
- The user has granted calendar access to the terminal application. If access is denied, EventKit returns an empty calendar list and setup should fail with a clear error.
- zsh is the user's shell (macOS default since Catalina). The config path `~/.config/calendar-cli/config.toml` is shell-agnostic.
