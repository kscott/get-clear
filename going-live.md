# Get Clear — Going Live Checklist

Everything that needs to be completed, fixed, or built before the first PKG release
is in the hands of real people.

---

## Phase 0 — Unblock the PKG build

CI will fail until this is done. Nothing else in the pipeline is blocked by it — but
the signed PKG won't exist until it's complete.

- [ ] **Create Developer ID Installer cert**
  - developer.apple.com → Certificates → `+` → Developer ID Installer
  - Generate CSR in Keychain Access → Certificate Assistant → save to disk
  - Upload CSR, download `.cer`, double-click to install
  - Keychain Access → right-click cert → Export → save as `.p12` with password
  - Store and sync:
    ```bash
    security add-generic-password -s "get-clear-signing" -a "installer-p12-base64"   -w "$(base64 -i ~/installer.p12)" -U
    security add-generic-password -s "get-clear-signing" -a "installer-p12-password" -w "your-password" -U
    ~/dev/get-clear/scripts/sync-secrets
    ```
  - Push any change to get-clear/main to trigger CI and confirm the PKG is built, signed, and stapled

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
  - `calendar work today` (no config.toml) → "No calendars matched subset 'work'" — acceptable, but note that conclusion.html and README need to make config setup obvious

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

- [ ] **Shell completions** (get-clear #4)
  - zsh completions for all five tools
  - Tab-complete commands, list names, calendar subsets
  - Important for the "direct use" mode where people learn the vocabulary

- [ ] **Close resolved GitHub issues**
  - contacts #3 — multi-value email/phone — fixed ✓
  - contacts #14 — CoreData 134092 — fixed ✓ (if issue was filed; check)

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
| PKG won't build | Developer ID Installer cert |
| Nothing to point people to | README.md |
| Experience gaps | calendar setup command; full install walkthrough |
| Missing feedback loop | Activity log + done report |

The curl installer works today. The PKG works as soon as the cert exists.
The README is the unlock for sharing either one.
