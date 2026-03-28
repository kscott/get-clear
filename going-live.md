# Get Clear — Going Live Checklist

Everything that needs to be completed, fixed, or built before the first PKG release
is in the hands of real people.

---

## Phase 0 — Unblock the PKG build ✅

Complete as of 2026-03-14.

- [x] **Create Developer ID Installer cert** — created, imported, backed up to Secure Documents disk image
- [x] **Store in Keychain, sync to GitHub** — `get-clear-signing` Keychain entries updated, `sync-secrets` run
- [x] **CI green, PKG ships** — signed, notarized, stapled `get-clear.pkg 1.0.0` live at GitHub releases
- [x] **Stapler bug fixed across all five tool repos** — contacts, reminders, calendar, mail, sms
- [x] **Semantic versioning** — `VERSION` file + `scripts/bump-version`
- [x] **Uninstaller** — `scripts/uninstall`; prompts to remove config/credentials; bundled in PKG at `/usr/local/share/get-clear/uninstall.sh`

---

## Phase 1 — The front door

The PKG without a README to point at is useless. This is the story before the install.

- [ ] **README.md** (umbrella repo)
  - Opens with the origin sentence
  - Tells the story: the itch, who this is for, what it does
  - Install section: PKG download link + curl one-liner as alternative
  - Link to setup guide for post-install steps
  - Feedback link to get-clear issues

- [ ] **why.md** (umbrella repo)
  - The longer version, for people who want to understand before they install
  - Workflow examples from vision.md
  - The feeling — what "get clear" actually means

---

## Phase 2 — Validate the install experience

Nothing embarrassing should make it to a real person. Test this end to end.

- [ ] **Test PKG on a clean macOS account or VM**
  - Create a new local user account (System Settings → Users & Groups) — simplest clean-slate option
  - Download get-clear.pkg from GitHub releases
  - Double-click, run through the installer
  - Confirm Gatekeeper accepts the signed + stapled PKG without a warning
  - Confirm postinstall opens the README in a browser
  - **Note:** CI smoke test (release.yml) automatically confirms binaries install and execute on every release — this manual step focuses on Gatekeeper acceptance and permission prompts only

- [ ] **Test curl installer on a clean shell**
  ```bash
  curl -fsSL https://raw.githubusercontent.com/kscott/get-clear/main/install.sh | bash
  ```
  - Confirm all five binaries download successfully
  - Confirm PATH is patched in `~/.zshrc` if `~/.local/bin` isn't already there
  - Confirm next-steps output is clear

- [ ] **Walk through first-run permissions for each tool**
  - `reminders list` — approves Reminders access
  - `calendar today` — approves Calendar access
  - `contacts lists` — approves Contacts access
  - `sms open` — approves Automation/Messages access
  - Confirm each permission prompt is clear and approves correctly

- [ ] **Verify mail setup onboarding flow**
  - `mail send` before setup → should print "No JMAP token — run 'mail setup' first" ✓ (already handled)
  - `mail setup <token>` → confirm it discovers identities and stores to Keychain cleanly

- [ ] **Verify calendar without config**
  - `calendar today` (no config.toml) → shows all calendars — acceptable
  - `calendar work today` (no config.toml) → "No calendars matched subset 'work'" — acceptable, but conclusion.html and README need to make config setup obvious

---

## Phase 3 — Code gaps that affect real users

These aren't bugs — the tools work — but they're missing pieces that will come up
quickly once real people use them.

- [x] **Activity log, what, and recap** (get-clear #1, #2)
  - Every write command across all five tools logs a timestamped entry to `~/.local/share/get-clear/log/`
  - `get-clear what [range]` / `<tool> what [range]` — complete action log
  - `get-clear recap [range]` — commitments kept: calendar events, completed reminders, mail/sms sent
  - FR-018 midnight recency rule — never shows empty when you just finished a full day
  - Shipped 2026-03-19; branch `001-activity-log`

- [x] **calendar setup** (calendar #11)
  - Guided, interactive config.toml creation: `calendar setup`
  - Shows available calendars numbered with true-color dots
  - Accepts number or name input; writes `[subsets]` TOML
  - Shipped 2026-03-15

- [x] **Shell completions** (get-clear #4)
  - zsh completions for all five tools
  - Tab-complete commands, list names, calendar subsets
  - PKG bundles to `/usr/local/share/zsh/site-functions/`; curl installer patches fpath

- [ ] **Gmail support** (mail #14)
  - The majority of the target audience is on Gmail or Google Workspace
  - Shipping without Gmail means mail doesn't work for most users on day one
  - OAuth2 flow, Google Cloud Console app registration, browser consent
  - Workspace/Okta environments may require IT admin approval — outside our control
  - `mail setup gmail` triggers OAuth flow; `mail setup fastmail <token>` stays as-is
  - Setup section in README needs two paths once this ships
  - **This is a launch blocker — do not ship publicly until Gmail works**

- [ ] **MCP mail attachments** (get-clear #20)
  - `mail send` already supports attachments in the binary; MCP tool doesn't expose it
  - Gap affects every Claude user sending mail with attachments — primary interface

- [ ] **`--help` flag guard** (get-clear #28, partial)
  - `--help` passed to any command is silently treated as content — creates a reminder named "--help", sends mail to "--help", etc.
  - Fix: intercept `--help` / `-h` before argument parsing and show subcommand help instead
  - Silent data corruption; applies to all five tools

- [ ] **Emoji shortcode expansion** (get-clear #17)
  - `:tada:` → 🎉, `:rocket:` → 🚀 etc. in all user-supplied text fields
  - Expansion function in GetClearKit, curated ~150 shortcode dictionary, no runtime dependency
  - Small scope, high delight for a Claude-first tool

- [x] **Color output pass** (get-clear #10)
  - All five tools: bold names/titles, dim metadata, red errors
  - isatty + NO_COLOR detection — ANSI suppressed when piped
  - Shipped 2026-03-15; closed get-clear #10

- [x] **GetClearKit: shared fail()** (get-clear #12)
  - `Fail.swift` in GetClearKit — red-prefixed error, exit non-zero
  - All five tools wired; shipped 2026-03-15; closed get-clear #12

- [x] **GetClearKit: shared date parsing** (get-clear #11)
  - `DateParser.swift` — ParsedDate, parseDate(), formatDate()
  - `RangeParser.swift` — ParsedRange, parseRange(), parseSingleDate(), formatRangeDescription()
  - 185 tests in GetClearKit test suite; RemindersLib + CalendarLib stubs removed
  - Shipped 2026-03-15; closed get-clear #11

- [x] **GetClearKit: standard flag handling** (get-clear #13)
  - `Flags.swift` — isVersionFlag(), isHelpFlag() shared across all tools
  - Shipped 2026-03-15; closed get-clear #13

- [x] **Update notifier** (new)
  - `UpdateChecker` in GetClearKit — pkgutil version detection, cache read/write, semver comparison, background spawn
  - `get-clear check-update` hidden subcommand — hits GitHub API, writes cache; silent
  - `get-clear update` — compares versions, downloads PKG, warns about password, opens Installer.app
  - ⭐ hint on stderr after stdout, at most once per hour; wired into all five tools + get-clear commands
  - CI now creates versioned `v{VERSION}` tag alongside rolling `latest` tag
  - Shipped 2026-03-19; v1.2.0

- [x] **Close resolved GitHub issues**
  - contacts #3 — multi-value email/phone — closed ✓
  - contacts #14 — CoreData 134092 — never filed; fix shipped in same session as #3

---

## Phase 4 — Post-v1

Good problems to have. Build after real users are using the tools and giving feedback.

- [ ] **Contextual subcommand help** (get-clear #28, partial)
  - `help <subcommand>` currently falls through to full help; should filter to the relevant block
  - Companion to the `--help` guard fix already in Phase 3

- [ ] **MCP compiled binary** (get-clear #27)
  - MCP server currently a Python script requiring the source repo to be cloned
  - Ship as `get-clear mcp` or `reminders mcp` compiled subcommand so MCP works on a fresh install
  - Becomes important once distributing to real users

- [ ] **mail: no-backend fallback** (mail #17)
  - If no token configured, fall back to `mailto:` or clipboard instead of erroring
  - Niche edge case once Gmail ships — covers providers outside Fastmail/Gmail

- [ ] **mail draft command** (mail #18)
  - Explicit "stage it, don't send it" workflow via mailto:/clipboard
  - Distro list composition: contacts group → paste-ready To: block

- [ ] **mail find + reply** (mail #10, #11)
  - Numbered results from `mail find`, referenceable by ID
  - `mail reply <n>` to respond in-thread
  - Completes the mail loop for Claude-assisted use

- [ ] **Gmail support** (mail #14)
  - Moved to Phase 3 — confirmed launch blocker

- [ ] **JMAP session cache** (mail #4)
  - Cache session and mailbox IDs instead of fetching on every command
  - Performance win, not correctness fix

- [x] **MCP server** (get-clear #3)
  - 22 tools across all five CLIs; lives in `mcp/`
  - Typed parameters eliminate CLI string-construction ambiguity
  - Setup: `python3 -m venv .venv && .venv/bin/pip install mcp && claude mcp add get-clear ...`
  - Shipped 2026-03-16

- [ ] **Google Calendar** (calendar #12)
  - Same scope concern as Gmail — evaluate post-v1

- [ ] **Multi-recipient SMS** (sms #10)

- [ ] **Move reminder to different list** (reminders #13)

- [ ] **Automated release tagging** (get-clear #9)
  - Semantic versioning, GitHub releases with proper tags
  - Current approach (rolling `latest` tag) is fine for now

---

## Summary — what's actually blocking launch

| Phase | Blocker | What's needed |
|---|---|---|
| 0 | ~~PKG won't build~~ | ~~Developer ID Installer cert~~ ✅ |
| 1 | Nothing to point people to | README.md + why.md |
| 2 | Install experience unvalidated | Clean-machine PKG + curl installer test |
| 3 | ~~Missing feedback loop~~ | ~~Activity log + done report~~ ✅ |
| 3 | mail doesn't work for most users | Gmail support (mail #14) |
| 3 | MCP missing binary feature | mail attachments via MCP (#20) |
| 3 | Silent data corruption | `--help` flag guard (#28) |
| 3 | Polish | Emoji shortcode expansion (#17) |
| 3 | ~~Experience gaps~~ | ~~calendar setup command~~ ✅ |
| 3 | ~~Incomplete vision~~ | ~~Color output, GetClearKit migrations (#10–13)~~ ✅ |

The PKG is built, signed, and live. Phases 1–3 must all be complete before sharing with real people.
