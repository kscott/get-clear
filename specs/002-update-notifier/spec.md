# Feature Specification: Update Notifier

**Feature Branch**: `002-update-notifier`
**Created**: 2026-03-19
**Status**: Ratified (2026-03-19)
**Input**: User description: "When a new version ships, the user should find out the next time they use any tool — without checking anything manually. `get-clear update` downloads and installs the new PKG. Tools handle what they can; they do not push work back to the user."

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Find out without looking (Priority: P1)

A new version of Get Clear ships. The user doesn't know. They run `reminders add Call Sarah friday` as they always do. The reminder is created. Then, on stderr, one line: `  get-clear 1.1.3 available — run get-clear update to install`. They finish what they're doing, run the command when ready. That's the whole interaction. No app to open. No release page to monitor. The tool took care of knowing.

**Why this priority**: This is the premise. Without it, every subsequent version of Get Clear requires the user to discover it on their own — the suite stops being self-reliant.

**Independent Test**: Manually set the cached latest version to a value higher than the installed version. Run any tool. Confirm the hint appears on stderr after the tool's normal output. Confirm stdout is unaffected.

**Acceptance Scenarios**:

1. **Given** a newer version is available (per cache), **When** the user runs any tool command, **Then** a one-line hint appears on stderr after all stdout output, naming the available version, the update command, and a direct link to the release notes for that version.
2. **Given** the user is on the latest version, **When** they run any tool command, **Then** no hint appears.
3. **Given** the tool is not installed via PKG (dev machine — `pkgutil` finds no package), **When** the user runs any tool command, **Then** no hint appears and no background check runs.
4. **Given** a hint was shown, **When** the user runs another tool command before updating, **Then** the hint appears again — it persists until the user updates.
5. **Given** the output of a tool is piped to another command, **When** a newer version is available, **Then** the hint still appears on stderr (not stdout), so piped output is unaffected.

---

### User Story 2 — Update with one command (Priority: P1)

The user sees the hint. They run `get-clear update`. The tool prints what it's doing: checking the installed version, confirming a newer one is available, downloading the PKG. Before opening the installer, it tells them a password will be required to complete installation. Installer.app opens. They enter their password. Done. No browser. No downloads folder. No manual steps.

**Why this priority**: The hint without the update command is half a promise. The suite must be able to close the loop entirely.

**Independent Test**: With a newer version available in the cache, run `get-clear update`. Confirm it prints progress, warns about the password, opens Installer.app with the correct PKG, and exits cleanly.

**Acceptance Scenarios**:

1. **Given** a newer version is available, **When** the user runs `get-clear update`, **Then** it downloads the latest PKG to a temp directory, warns that a password will be required, and opens it in Installer.app.
2. **Given** `get-clear update` is run while already on the latest version, **When** the installed version matches the cached latest (or a fresh check confirms it), **Then** it prints "Already on the latest version (X.Y.Z)." and exits without downloading anything.
3. **Given** the network is unavailable during `get-clear update`, **When** the download fails, **Then** it prints a clear error and exits non-zero — no partial state left behind.
4. **Given** `get-clear update` is run on a dev machine (not installed via PKG), **When** `pkgutil` finds no package, **Then** it prints "get-clear update is only available for PKG installs. Download from https://github.com/kscott/get-clear/releases." and exits cleanly.
5. **Given** the cache is stale (older than 1 hour) when `get-clear update` is run, **When** it checks the installed version, **Then** it performs a fresh check against GitHub before comparing — so it never reports "already up to date" based on stale data.

---

### User Story 3 — The background check is invisible (Priority: P2)

The user runs `calendar today`. It returns instantly. They don't know or care that a background process has quietly checked GitHub for a new version and written a result to a cache file. The check has no observable effect on the tool's response time — it runs entirely after the tool has done its work, in a detached process.

**Why this priority**: An update check that adds latency violates the tool's implicit contract. Speed is not a nice-to-have.

**Independent Test**: Time `calendar today` with and without a forced background check. Confirm no measurable difference.

**Acceptance Scenarios**:

1. **Given** any tool invocation, **When** the background check fires, **Then** the tool's measured response time is not affected.
2. **Given** two tools run in rapid succession within the same hour, **When** the first fires a background check, **Then** the second does not — the cache timestamp prevents a redundant check.
3. **Given** the network is unavailable when the background check fires, **When** the check fails, **Then** the tool output is unaffected, no error appears, and the check is retried on the next invocation after the cache expires.

---

## Edge Cases

**Network unavailable during background check**
Silent failure. The cache is not updated. The next invocation after the cache expires will try again. No error, no output, no user-visible effect.

**Network unavailable during `get-clear update`**
Not silent — the user asked for a specific action. Print a clear error: "Could not reach GitHub. Check your connection and try again." Exit non-zero.

**Concurrent tool invocations**
Two tools run simultaneously; both attempt to spawn a background check. The cache write is atomic. The last writer wins — both will write the same result. No corruption risk. Redundant network calls are acceptable at this frequency.

**Version already current when `get-clear update` runs**
No download. "Already on the latest version (X.Y.Z)." The installed version is read from `pkgutil`; the latest is read from cache (or a fresh check if stale). Compare before touching the network or filesystem.

**Installer.app already open**
`open` on the PKG will hand it to the existing Installer.app session. macOS handles this gracefully.

**PKG download interrupted**
Temp file is left behind. On next run, a fresh download begins. Temp files live in `/tmp/` and are cleaned up by macOS on reboot.

**Dev machine — no PKG install**
`pkgutil --pkg-info com.kenscott.get-clear` returns a non-zero exit code. Both the background check and `get-clear update` skip entirely. No error, no hint. The dev loop is unaffected.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: On every invocation of any tool in the suite, after the tool's stdout output is complete, the update notifier MUST check a local cache file to determine whether a newer version is available.
- **FR-002**: If a newer version is available (per cache), the notifier MUST print a single line to stderr. Format: `⭐ get-clear X.Y.Z available — run: get-clear update  (what's new: https://github.com/kscott/get-clear/releases/tag/X.Y.Z)`. The text following the emoji MUST be styled dim (respecting `ANSI.enabled`). The emoji renders in its natural color and is not wrapped in ANSI codes. The changelog URL MUST be constructed from the cached version string — no additional network call is required.
- **FR-003**: The hint MUST appear on stderr only — never on stdout. Piped output MUST be unaffected.
- **FR-004**: The hint MUST appear after all tool stdout output. It MUST NOT appear before or interleaved with the tool's results.
- **FR-005**: On every invocation, if the cache is older than 1 hour, the notifier MUST spawn a background process to refresh it. The background process MUST be fully detached — it MUST NOT add latency to the tool invocation.
- **FR-006**: The background check MUST query the GitHub Releases API for the latest published release and write the result (latest version string + timestamp) to the cache file.
- **FR-007**: If `pkgutil --pkg-info com.kenscott.get-clear` returns a non-zero exit code, neither the background check nor the hint MUST fire. The notifier is a no-op on non-PKG installs.
- **FR-008**: The cache file MUST be stored at `~/.local/share/get-clear/update-check.json`. It MUST contain the latest version string and the timestamp of the last successful check.
- **FR-009**: `get-clear update` MUST read the installed version from `pkgutil` and compare it to the cached latest version. If the cache is stale (older than 1 hour), it MUST perform a fresh check before comparing.
- **FR-010**: If the installed version matches the latest, `get-clear update` MUST print "Already on the latest version (X.Y.Z)." and exit zero without downloading anything.
- **FR-011**: If a newer version is available, `get-clear update` MUST print progress to stdout as it works: confirming the versions, beginning the download, confirming the download completed. Before opening the installer, it MUST print a clear warning that a password will be required to complete installation.
- **FR-012**: `get-clear update` MUST download the PKG from the GitHub release asset URL to a temp directory, then open it with `open`, handing control to Installer.app.
- **FR-013**: `get-clear update` MUST exit after opening the installer — it does not wait for installation to complete.
- **FR-014**: If `pkgutil` finds no package, `get-clear update` MUST print an explanation and the releases URL, then exit cleanly.
- **FR-015**: Network failures during `get-clear update` MUST produce a clear error message and a non-zero exit code.
- **FR-016**: Network failures during the background check MUST be silent. The cache is not updated. The notifier retries on the next invocation after the cache window expires.
- **FR-017**: The background check MUST be implemented as a hidden subcommand of the `get-clear` binary itself (`get-clear check-update`), so no additional binary or shell script needs to be bundled or maintained. The subcommand MUST be handled in the dispatch switch but MUST NOT appear in `usage()` output.
- **FR-018**: Version comparison MUST use semantic versioning rules — a higher major, minor, or patch number constitutes a newer version.

### Design Principle (suite-wide)

A tool that surfaces a problem it cannot solve has failed. `get-clear update` exists because the hint would otherwise push work back onto the user. **Tools in this suite handle what they can. They do not hand work back to the user unless the operating system makes it genuinely impossible.** The password prompt in Installer.app is the OS enforcing a security boundary — not the tool abdicating responsibility. Everything up to that moment is the tool's job.

This principle applies across the suite. When a new feature creates an action the user would otherwise have to take manually, ask whether the tool can take it instead before designing a user-facing instruction.

### Key Entities

- **Cache file**: `~/.local/share/get-clear/update-check.json` — `{"latest": "1.1.3", "checked": "2026-03-19T16:00:00Z"}`
- **Installed version**: read from `pkgutil --pkg-info com.kenscott.get-clear`, `version:` field
- **Latest version**: read from GitHub Releases API `tag_name` field, stripped of leading `v` if present
- **Background check**: detached invocation of `get-clear --check-update`; hits API, writes cache, exits
- **Hint**: one stderr line, shown after stdout, only when installed version < latest version

---

## Success Criteria *(mandatory)*

- **SC-001**: A user who never visits GitHub learns about every new release of Get Clear within one hour of their next tool use after it ships.
- **SC-002**: `get-clear update` completes the full update flow — from hint to Installer.app — without the user opening a browser, visiting a URL, or finding a downloads folder.
- **SC-003**: No tool invocation is measurably slower due to the update notifier. The background check is invisible.
- **SC-004**: Stdout from any tool is bit-for-bit identical whether or not a newer version is available. Scripts and pipes are unaffected.
- **SC-005**: A developer working directly from the built binary never sees a hint or update prompt.
- **SC-006**: `get-clear update` never downloads a PKG if the user is already on the latest version.

---

## Implementation Notes

**Background process**: `get-clear check-update` is the cleanest path — one binary, no shell script to bundle or version separately. The hidden subcommand does the check and exits. The calling tool spawns it with `Process()`, sets it to a new process group so it outlives the parent, and returns immediately. It does not appear in `usage()` — it is an internal detail, not a user-facing command.

**`check-update` requires no access control.** There is no technical barrier preventing a user who discovers the subcommand (via `strings`, curiosity, or documentation archaeology) from running it manually. This is intentional and acceptable. The subcommand's only effect is hitting the GitHub API and writing a cache file — the same thing the background invocation does. A manual run is a harmless no-op from the user's perspective. Obscurity (absent from `usage()`, undocumented) is sufficient. Do not add parent-process checks or other enforcement — the complexity is not justified by the risk.

**GetClearKit**: `UpdateChecker.swift` — reads the cache, determines whether the hint should show, spawns the background check. Shared across all five tools by virtue of being in GetClearKit.

**`get-clear` binary**: Handles `--check-update` hidden flag and the `update` command. Download logic, PKG open, version comparison against pkgutil output.

**GitHub API**: `https://api.github.com/repos/kscott/get-clear/releases/latest` → `tag_name`. No auth required for public repos at this call volume (1/hour at most, across all users).

**ANSI**: The hint prefix is `⭐` — renders in natural emoji color across all monospace fonts, no ANSI needed. The text following it is styled dim, respecting `ANSI.enabled` (NO_COLOR / isatty). The emoji occupies slightly more horizontal space than a single character; this is acceptable and expected.

**Changelog**: The hint includes a direct link to the GitHub release notes for the available version — `https://github.com/kscott/get-clear/releases/tag/X.Y.Z`. The URL is constructed from the cached version string at hint display time. No additional network call or stored URL is needed.
