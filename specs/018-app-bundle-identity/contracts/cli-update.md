# Contract: `get-clear update` and the update hint

Unchanged user surface; changed mechanism. Messages marked *(existing)* keep today's exact wording.

## Hint (stderr, after command output)
*(existing)* `  get-clear X.Y.Z available — run get-clear update to install`, shown when `InstalledApp.version` < latest cached version. Never shown when `AccessRoute` is `.direct`.

## `get-clear update`

| `UpdatePlan` | Output (stderr progress, stdout result) | Exit |
|---|---|---|
| `.notInstalledAsApp` | *(existing)* `get-clear update is only available for PKG installs. Download from https://github.com/kscott/get-clear/releases.`, unchanged (FR-014) | 0 |
| `.upToDate(v)` | *(existing)* `Already on the latest version (v).` | 0 |
| `.selfUpdate` | `Downloading Get Clear v…` / `Verifying signature…` / `Installing…` / `Get Clear updated to v.` | 0 |
| `.pkgFallback` | `Get Clear can't replace itself in <dir> — opening the installer instead. A password will be required.` then the existing PKG flow | 0 |
| verification fails | `Error: The downloaded update isn't signed by Get Clear's developer — not installed. Your current version (v) is unchanged.` | 1 |
| download fails | `Error: Couldn't download the update: <reason>. Your current version (v) is unchanged.` | 1 |

Staging is removed on every path, including failures.

## Release assets (per tag)
- `get-clear.pkg` — first install and fallback; also what 1.3.x's updater fetches (FR-022)
- `Get-Clear.zip` — notarized, stapled `Get Clear.app`
