# Contract: `get-clear update` and the update hint

Unchanged user surface; changed mechanism. Messages marked *(existing)* keep today's exact wording.

## Hint (stderr, after command output)
*(existing, exact)* `⭐ get-clear X.Y.Z available — run: get-clear update  (what's new: <release URL>)`, dim, shown when `InstalledApp.version` < latest cached version. Never shown when `AccessRoute` is `.direct`.

The cache (`~/.local/share/get-clear/update-check.json`) keeps 1.3.x's keys (`version`, `url` = the PKG, `checked`) and adds `appURL`, so old and new versions share it.

## `get-clear update`

| `UpdatePlan` | Output (stderr progress, stdout result) | Exit |
|---|---|---|
| `.notInstalledAsApp` | *(existing, exact)* `get-clear update is only available for PKG installs.` / `Download from https://github.com/kscott/get-clear/releases` (FR-014) | 0 |
| `.upToDate(v)` | *(existing)* `Already on the latest version (v).` | 0 |
| `.selfUpdate` | `Downloading Get Clear v…` / `Verifying signature…` / `Installing…` / `Get Clear updated to v.` | 0 |
| `.pkgFallback` (not writable) | `Get Clear can't replace itself in <dir> — opening the installer instead. A password will be required.` then the existing PKG flow, its messages unchanged | 0 |
| `.pkgFallback` (release has no app archive) | the existing PKG flow, unchanged | 0 |
| update not newer than installed | `Error: The downloaded update isn't newer than v — not installed. Your current version (v) is unchanged.` | 1 |
| verification fails | `Error: The downloaded update isn't signed by Get Clear's developer — not installed. Your current version (v) is unchanged.` | 1 |
| download fails | `Error: Couldn't download the update: <reason>. Your current version (v) is unchanged.` | 1 |

Staging is removed on every path, including failures.

**Ownership.** Installer leaves the app owned by root, which a self-update running as the user couldn't swap or delete. The PKG's postinstall gives the app to the console user (`chown -R <user>:admin`), the same ownership a drag-installed app has. `InstalledApp.writable` checks both the folder and the app.

## Release assets (per tag)
- `get-clear.pkg` — first install and fallback; also what 1.3.x's updater fetches (FR-022)
- `Get-Clear.zip` — notarized, stapled `Get Clear.app`
