# Implementation Plan: Update Notifier (002-update-notifier)

## Prerequisite — Switch to proper semver release tags

The repo currently uses a rolling `latest` tag for all releases. The GitHub Releases API returns `tag_name: "latest"` for every release — there is no version number to compare against. The update notifier cannot function without real semver tags (e.g., `v1.1.3`).

**Required before building the notifier:**
- Update CI (`release.yml`) to tag releases with `v{VERSION}` instead of overwriting `latest`
- The `scripts/bump-version` script already reads the `VERSION` file; CI needs to use that value as the git tag
- The GitHub Releases API `latest` endpoint (`/releases/latest`) returns the most recent non-draft, non-prerelease release — with proper tags, `tag_name` will be `"v1.1.3"`, which we strip to `"1.1.3"`
- Also store `browser_download_url` from the `assets` array in the cache — needed for `get-clear update` to download the PKG without a second API call
- This is tracked as get-clear #9 (Automated release tagging) — build it now, not later

---

## Phase 1 — GetClearKit: UpdateChecker.swift

New file in `Sources/GetClearKit/`. No changes to `Package.swift` required — files in the target directory are automatically included.

### Public API

```swift
public struct UpdateChecker {
    /// Returns the installed version string from pkgutil, or nil if not installed via PKG.
    public static func installedVersion() -> String?

    /// Returns cached latest version + check timestamp, or nil if no cache exists.
    public static func cachedLatest() -> (version: String, url: String, checked: Date)?

    /// Returns a hint string for stderr if a newer version is available, otherwise nil.
    /// Format: "⭐ {dim}get-clear X.Y.Z available — run: get-clear update  (what's new: URL){/dim}"
    public static func hint() -> String?

    /// Spawns `get-clear check-update` as a detached background process if cache is older than 1 hour.
    /// No-op if not installed via PKG. Returns immediately — does not add latency.
    public static func spawnBackgroundCheckIfNeeded()
}
```

### Implementation notes

**`installedVersion()`**
- Run `pkgutil --pkg-info com.kenscott.get-clear` via `Process()`
- If exit code is non-zero → return nil (not a PKG install)
- Parse output for `version:` field, return the value

**`cachedLatest()`**
- Read `~/.local/share/get-clear/update-check.json`
- Decode: `{ "version": "1.1.3", "url": "https://...", "checked": "2026-03-19T16:00:00Z" }`
- Return nil if file missing or malformed

**`hint()`**
- Call `installedVersion()` — nil → return nil
- Call `cachedLatest()` — nil → return nil (no data yet; background check will populate)
- Compare using semver rules (split on `.`, compare major/minor/patch as integers)
- If installed >= latest → return nil
- Build URL: `https://github.com/kscott/get-clear/releases/tag/v{version}`
- Return: `"⭐ \(ANSI.dim("get-clear \(latest) available — run: get-clear update  (what's new: \(url))"))"`

**`spawnBackgroundCheckIfNeeded()`**
- Call `installedVersion()` — nil → return immediately (no PKG install)
- Call `cachedLatest()` — if checked within last hour → return immediately
- Find `get-clear` binary: use `Bundle.main.executableURL` or fall back to `/usr/local/bin/get-clear`
- Spawn via `Process()`: executable = get-clear binary, arguments = `["check-update"]`
- Call `setpgid(pid, 0)` after `run()` to create a new process group — child survives parent exit
- Return immediately — do not call `waitUntilExit()`

**Cache file location**: `~/.local/share/get-clear/update-check.json`
The parent directory `~/.local/share/get-clear/` is created by the activity log on first use. `UpdateChecker` should call `createDirectory(withIntermediateDirectories: true)` before writing — safe to call even if directory exists.

---

## Phase 2 — get-clear: check-update subcommand

Hidden subcommand in `Sources/GetClear/main.swift`. Handled in the dispatch switch, absent from `usage()`.

```swift
case "check-update":
    // Hit GitHub Releases API
    // Write cache file
    // Exit silently — no output
    exit(0)
```

### Implementation

1. Build URLRequest for `https://api.github.com/repos/kscott/get-clear/releases/latest`
2. Set `User-Agent: get-clear` header (required by GitHub for unauthenticated requests)
3. Execute synchronously via `URLSession.shared.dataTask` + `DispatchSemaphore`
4. On network failure: exit 0 silently — cache is not updated, retry on next invocation
5. Parse JSON with `JSONSerialization`: extract `tag_name` (strip leading `v`), and `assets[0].browser_download_url`
6. Write cache atomically to `~/.local/share/get-clear/update-check.json`:
   ```json
   { "version": "1.1.3", "url": "https://github.com/.../get-clear.pkg", "checked": "2026-03-19T16:00:00Z" }
   ```
7. Exit 0

---

## Phase 3 — get-clear: update command

User-facing subcommand. Appears in `usage()`. Lives in `Sources/GetClear/main.swift`.

```swift
case "update":
    // Full update flow
```

### Implementation

1. Call `UpdateChecker.installedVersion()` — if nil, print explanation + releases URL, exit 0
2. Read cached latest; if stale (>1 hour), do a fresh synchronous check first (same logic as `check-update`)
3. Compare versions — if installed >= latest, print `"Already on the latest version (\(installed))."`, exit 0
4. Print: `"Updating get-clear \(installed) → \(latest)..."`
5. Print: `"Downloading get-clear \(latest)..."`
6. Download PKG from cached URL to `/tmp/get-clear-\(latest).pkg` via `URLSession` + semaphore
7. On download failure: print error, remove partial file if it exists, exit non-zero
8. Print: `"Download complete."`
9. Print: `"A password will be required to complete installation."`
10. Run `open /tmp/get-clear-\(latest).pkg` via `Process()`
11. Exit 0 — do not wait for installation

---

## Phase 4 — Wire into get-clear commands

In `Sources/GetClear/main.swift`, each existing command (`what`, `recap`, `setup`) gets two additions:

**At the start of each command** (before doing any work):
```swift
UpdateChecker.spawnBackgroundCheckIfNeeded()
```

**After all output** (after `semaphore.wait()` where applicable, or after `print()`):
```swift
if let hint = UpdateChecker.hint() { fputs(hint + "\n", stderr) }
```

The `check-update` and `update` commands do NOT show the hint — they are update-related themselves.

---

## Phase 5 — Wire into all five tool repos

Each tool's `main.swift` needs the same two additions as Phase 4. The tool repos depend on GetClearKit via `branch: "main"` — once `UpdateChecker.swift` is merged to get-clear main, all five tool repos can import and use it.

In each tool, after `semaphore.wait()`:
```swift
UpdateChecker.spawnBackgroundCheckIfNeeded()
if let hint = UpdateChecker.hint() { fputs(hint + "\n", stderr) }
```

**Binary path for background check**: When a tool spawns `get-clear check-update`, it needs to find the `get-clear` binary. On PKG installs, `get-clear` is at `/usr/local/bin/get-clear`. Hard-code this path — if the binary isn't there, `Process().run()` will throw, which we catch and swallow silently.

Tools to update: reminders-cli, calendar-cli, contacts-cli, mail-cli, sms-cli.

---

## Phase 6 — CI: add semver tags alongside rolling `latest`

Update `get-clear/.github/workflows/release.yml`:
- Read `VERSION` file content
- Create git tag `v{VERSION}` on the release commit and use it for the GitHub Release — `tag_name` will now be `"v1.1.3"` rather than `"latest"`
- Also update the rolling `latest` tag as before — the curl installer, direct download links, and anything else that hardcodes `latest` continues to work without change
- The GitHub API `/releases/latest` endpoint returns the most recent non-draft, non-prerelease release — with proper semver tags it will return `tag_name: "v1.1.3"`, which we strip to `"1.1.3"` for version comparison

This is a one-time CI change. Future `bump-version` + push creates both a versioned tag and updates `latest`.

---

## Phase 7 — Tests

Add to `Tests/GetClearKitTests/main.swift`:
- Version comparison: `1.1.3 > 1.1.2`, `1.2.0 > 1.1.9`, `2.0.0 > 1.9.9`, `1.1.2 == 1.1.2`, `1.1.1 < 1.1.2`
- Cache parsing: valid JSON, missing file, malformed JSON, stale vs. fresh timestamp
- `hint()` returns nil when installed == latest
- `hint()` returns nil when installed > latest (already newer — edge case on dev)
- `hint()` returns nil when no cache file exists

---

## Build order

1. CI tag fix (Phase 6) — unblocks everything; needs to ship before the notifier is useful
2. `UpdateChecker.swift` in GetClearKit + tests (Phase 1)
3. `check-update` subcommand in get-clear (Phase 2)
4. `update` command in get-clear (Phase 3)
5. Wire get-clear commands (Phase 4)
6. Merge get-clear → tool repos can now import UpdateChecker
7. Wire all five tool repos (Phase 5)
8. Bump version, release

---

## Open questions

- **`setpgid` in Swift**: Confirmed available via `import Darwin`. Call after `p.run()` using `p.processIdentifier`.
- **`get-clear` binary path in tool repos**: Hard-code `/usr/local/bin/get-clear`. If not found, `Process().run()` throws — catch and return silently. Dev machines have no PKG install so `installedVersion()` returns nil first, short-circuiting before the spawn.
- **PKG download URL**: Stored in the cache from the last `check-update` run. If cache is missing the URL field (first run or old cache format), do a fresh check before downloading.
