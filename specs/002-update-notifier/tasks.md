# Tasks: Update Notifier (002-update-notifier)

## GetClearKit

- [ ] Add `UpdateChecker.swift` to GetClearKit
  - [ ] Read installed version via `pkgutil --pkg-info com.kenscott.get-clear`; return nil if not found (dev machine)
  - [ ] Read cache file at `~/.local/share/get-clear/update-check.json`
  - [ ] Compare installed version to cached latest using semver rules
  - [ ] Expose `hint() -> String?` — returns formatted hint line or nil (nil if up to date, no cache, or not PKG install)
  - [ ] Expose `spawnBackgroundCheck()` — fires `get-clear check-update` as detached process if cache is older than 1 hour
- [ ] Add tests for `UpdateChecker`
  - [ ] Version comparison (older, same, newer — all three semver components)
  - [ ] Cache parse (valid JSON, missing file, malformed)
  - [ ] Hint returns nil when installed == latest
  - [ ] Hint returns nil when pkgutil finds no package
  - [ ] Background check not spawned when cache is fresh

## get-clear binary

- [ ] Add `check-update` hidden subcommand to `main.swift` (handled in dispatch switch, absent from `usage()`)
  - [ ] Hit GitHub Releases API (`/repos/kscott/get-clear/releases/latest`)
  - [ ] Parse `tag_name`, strip leading `v`
  - [ ] Write `~/.local/share/get-clear/update-check.json` atomically
  - [ ] Exit 0 silently on success or network failure
- [ ] Add `update` command to `main.swift`
  - [ ] Read installed version from pkgutil; exit with explanation if not found
  - [ ] Read cached latest; perform fresh check if cache is stale (>1 hour)
  - [ ] If installed == latest: print "Already on the latest version (X.Y.Z)." and exit
  - [ ] Print progress: versions being compared, download beginning
  - [ ] Download PKG from GitHub release asset URL to `/tmp/get-clear-X.Y.Z.pkg`
  - [ ] Print password warning before opening installer
  - [ ] Open PKG with `open /tmp/get-clear-X.Y.Z.pkg`
  - [ ] Exit 0 after open (do not wait for installation)
  - [ ] Handle network failure: print error, exit non-zero, remove partial download
- [ ] Wire hint + background check into all three `get-clear` commands (`what`, `recap`, `setup`)
  - [ ] Call `UpdateChecker.spawnBackgroundCheck()` at start of each command
  - [ ] Call `UpdateChecker.hint()` at end of each command; print to stderr if non-nil

## Tool repos — wire hint + background check

- [ ] `reminders-cli` — add UpdateChecker calls to all commands
- [ ] `calendar-cli` — add UpdateChecker calls to all commands
- [ ] `contacts-cli` — add UpdateChecker calls to all commands
- [ ] `mail-cli` — add UpdateChecker calls to all commands
- [ ] `sms-cli` — add UpdateChecker calls to all commands

## Tests

- [ ] Add integration test: hint appears on stderr, not stdout
- [ ] Add integration test: no hint when installed == latest
- [ ] Add integration test: `get-clear update` exits cleanly when already up to date
- [ ] Add integration test: `check-update` subcommand writes valid cache file

## Polish

- [ ] Confirm hint respects `NO_COLOR` / non-tty (dim ANSI stripped when piped)
- [ ] Confirm background check does not appear in `ps` output after parent exits
- [ ] Update `going-live.md` — mark update notifier complete
- [ ] Close relevant GitHub issues
- [ ] Bump version and release
