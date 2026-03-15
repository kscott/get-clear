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
  - Download get-clear.pkg from GitHub releases
  - Double-click, run through the installer
  - Confirm all five tools land in `/usr/local/bin` and are executable
  - Confirm Gatekeeper accepts the signed + stapled PKG without a warning
  - Confirm postinstall opens the README in a browser

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

- [ ] **Activity log + reminders done report** (get-clear #1, #2)
  - Every action across all five tools writes a timestamped log entry
  - `get-clear what` / `reminders what` / `calendar what` to review
  - This is the feedback loop. Without it, the suite helps you do things but doesn't
    show you that you're doing them. Load-bearing for the vision.

- [ ] **calendar setup** (calendar #11)
  - Guided, interactive config.toml creation: `calendar setup`
  - Shows available calendars, asks which to group as work/personal
  - Removes the manual TOML step for non-technical users
  - Blocked on: nothing — ready to build

- [x] **Shell completions** (get-clear #4)
  - zsh completions for all five tools
  - Tab-complete commands, list names, calendar subsets
  - PKG bundles to `/usr/local/share/zsh/site-functions/`; curl installer patches fpath

- [ ] **mail: no-backend fallback** (new)
  - If no JMAP token is configured, `mail send` falls back instead of erroring:
    - Single recipient → `open mailto:...` — opens the user's default mail client pre-filled
    - Multiple recipients or long body → copy to clipboard in paste-ready format
  - Auto-detected from whether `mail setup` has been run — user never has to think about it
  - This makes mail work for everyone on day one, regardless of email provider

- [ ] **mail draft command** (new)
  - Explicit "stage it, don't send it" workflow — always uses mailto:/clipboard path
  - Works even with JMAP configured, for people who want to review before sending
  - Covers distro list composition: resolves a contacts group → paste-ready To: block

- [x] **Close resolved GitHub issues**
  - contacts #3 — multi-value email/phone — closed ✓
  - contacts #14 — CoreData 134092 — never filed; fix shipped in same session as #3

---

## Phase 4 — Post-v1

Good problems to have. Build after real users are using the tools and giving feedback.

- [ ] **mail find + reply** (mail #10, #11)
  - Numbered results from `mail find`, referenceable by ID
  - `mail reply <n>` to respond in-thread
  - Completes the mail loop for Claude-assisted use

- [ ] **Gmail support** (get-clear #5, mail #14)
  - Opens the suite to the majority of email users
  - Significant scope: Google API auth, OAuth flow, MIME handling
  - Evaluate after v1 — don't let it block launch

- [ ] **JMAP session cache** (mail #4)
  - Cache session and mailbox IDs instead of fetching on every command
  - Performance win, not correctness fix

- [ ] **MCP server** (get-clear #3)
  - Expose the full suite to Claude via MCP
  - Lives in get-clear repo under `mcp/`
  - Build after the tools themselves are stable

- [ ] **Google Calendar** (calendar #12)
  - Same scope concern as Gmail — evaluate post-v1

- [ ] **Multi-recipient SMS** (sms #10)

- [ ] **Move reminder to different list** (reminders #13)

- [ ] **Automated release tagging** (get-clear #9)
  - Semantic versioning, GitHub releases with proper tags
  - Current approach (rolling `latest` tag) is fine for now

---

## Summary — what's actually blocking launch

| Blocker | What's needed |
|---|---|
| ~~PKG won't build~~ | ~~Developer ID Installer cert~~ ✅ |
| Nothing to point people to | README.md |
| Experience gaps | calendar setup command; full install walkthrough |
| mail broken for non-Fastmail users | No-backend fallback (mailto: / clipboard) |
| Missing feedback loop | Activity log + done report |

The PKG is built, signed, and live. The README is the unlock for sharing it.
