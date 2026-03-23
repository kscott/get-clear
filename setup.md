# Get Clear — Machine Setup

Complete setup guide for a new machine. Do this in order.

---

## Prerequisites

```bash
xcode-select --install    # Xcode Command Line Tools — skip if already installed
```

`~/bin` must be in your PATH. If you have dotfiles set up, this is already done.

---

## 1. Clone the repos

```bash
git clone https://github.com/kscott/reminders-cli ~/dev/reminders-cli
git clone https://github.com/kscott/calendar-cli ~/dev/calendar-cli
git clone https://github.com/kscott/contacts-cli ~/dev/contacts-cli
git clone https://github.com/kscott/mail-cli ~/dev/mail-cli
git clone https://github.com/kscott/sms-cli ~/dev/sms-cli
git clone https://github.com/kscott/get-clear ~/dev/get-clear
```

---

## 2. Build and install the tools

Each `setup` command builds the release binary, installs it to `~/bin`, and symlinks the wrapper script.

```bash
~/dev/reminders-cli/reminders setup
~/dev/calendar-cli/calendar setup
~/dev/contacts-cli/contacts setup
~/dev/sms-cli/sms setup
```

Mail is last — it needs a token (see step 3).

---

## 3. Fastmail JMAP token

Create a **fresh token per machine** — one token per machine makes it easy to revoke independently if needed.

1. Go to Fastmail → **Settings → Privacy & Security → API tokens**
2. Click **New token**
3. Name it clearly: `get-clear-home` or `get-clear-work`
4. Scope: **JMAP** (read + send)
5. Copy the token

Then run:

```bash
~/dev/mail-cli/mail setup <your-token>
```

This builds the binary, stores the token in macOS Keychain, and discovers your mail identities. Safe to re-run — it reuses an existing token if one is already stored.

**Verify it worked:**
```bash
mail find "test"
```

---

## 4. Calendar config

Create `~/.config/calendar-cli/config.toml` to define named subsets:

```toml
[subsets]
work     = ["Work", "Meetings"]
personal = ["Home", "Family"]
```

Adjust calendar names to match what's in Calendar.app on this machine. Run `calendar calendars` to see exactly what's available.

---

## 5. MCP server (Claude Code integration)

Exposes all five tools to Claude directly, without constructing CLI commands.

```bash
cd ~/dev/get-clear/mcp
python3 -m venv .venv
.venv/bin/pip install mcp
claude mcp add get-clear -- ~/dev/get-clear/mcp/.venv/bin/python3 ~/dev/get-clear/mcp/server.py
```

Restart Claude Code. See [mcp/README.md](mcp/README.md) for full details.

---

## 7. LaunchAgent (daily auto-update)

Pulls all repos and rebuilds any tool that changed. Runs daily at 9am.

```bash
cp ~/dotfiles/launchagents/com.kenscott.git-pull.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.kenscott.git-pull.plist
```

---

## 8. First-run permissions

Each tool will prompt for macOS permissions on first use. Just approve them:

- **Reminders** — `reminders list`
- **Calendar** — `calendar today`
- **Contacts** — `contacts lists`
- **Messages** (Automation) — `sms open`
- **Mail** — handled by JMAP token, no system permission needed

---

## Recommended macOS settings

These aren't required, but they make Get Clear behave the way most people expect.

### Week start day

By default, macOS treats Sunday as the first day of the week — which affects how `get-clear recap last week`, `get-clear what this week`, and similar commands anchor their date ranges.

If your working week starts on Monday (or any other day), tell macOS:

**System Settings → General → Language & Region → First day of week**

Set it to Monday. Calendar.app, Reminders, and every app that reads from the system calendar — including Get Clear — will respect it immediately. No restart needed.

This is worth doing even if you don't use Get Clear, because it fixes week boundaries everywhere: Calendar grid views, date pickers inside apps like Reminders, widget date ranges, Shortcuts automations, and more. The change takes effect immediately — no restart required.

---

## Verify everything

```bash
reminders list
calendar today
contacts lists
mail find "test"
sms open
```

All five working — you're set up.

---

## Signing and distribution infrastructure

Signed, notarized binaries are published automatically to GitHub Releases on every push to main. This requires signing credentials stored in two places: the local Keychain (for running the sync script) and GitHub Actions secrets (for CI builds).

### First-time setup (one machine, done)

The following are already stored in the local Keychain under service `get-clear-signing`:

| Account | What it is |
|---|---|
| `p12-base64` | Base64-encoded Developer ID **Application** cert (.p12) — used by each tool's CI |
| `p12-password` | Password protecting the Application .p12 |
| `notarytool-password` | App-specific password for `xcrun notarytool` |
| `apple-id` | Apple ID (ken@optikos.net) |
| `team-id` | Apple Developer Team ID (6Q96Q79QN8) |
| `installer-p12-base64` | Base64-encoded Developer ID **Installer** cert (.p12) — used by the PKG CI |
| `installer-p12-password` | Password protecting the Installer .p12 |

**Creating the Developer ID Installer cert (one-time, not yet done):**

This is a separate cert from the Application cert. PKG signing requires it.

1. Go to [developer.apple.com](https://developer.apple.com) → Certificates → `+`
2. Choose **Developer ID Installer** → Continue
3. Generate a CSR in Keychain Access → Certificate Assistant → Request a Certificate From a Certificate Authority → save to disk
4. Upload the CSR, download the resulting `.cer`, double-click to install
5. In Keychain Access: right-click the new cert → Export → save as `.p12` with a password
6. Store and sync:

```bash
security add-generic-password -s "get-clear-signing" -a "installer-p12-base64"   -w "$(base64 -i /path/to/installer.p12)" -U
security add-generic-password -s "get-clear-signing" -a "installer-p12-password" -w "your-password" -U
~/dev/get-clear/scripts/sync-secrets
```

### Syncing secrets to GitHub

To push credentials to all tool repos and the umbrella repo:

```bash
~/dev/get-clear/scripts/sync-secrets
```

Run this after any credential rotation. Claude can run it too.

### When credentials need to change

**Certificate expired or revoked:**
1. Open Xcode → Settings → Accounts → Manage Certificates → create new Developer ID Application cert
2. Export from Keychain Access: right-click cert → Export → save as `.p12` with a password
3. Update Keychain and sync:
```bash
security add-generic-password -s "get-clear-signing" -a "p12-base64"   -w "$(base64 -i /path/to/new.p12)" -U
security add-generic-password -s "get-clear-signing" -a "p12-password" -w "your-password" -U
~/dev/get-clear/scripts/sync-secrets
```

**App-specific password rotated** (appleid.apple.com → Sign-In and Security → App-Specific Passwords):
```bash
security add-generic-password -s "get-clear-signing" -a "notarytool-password" -w "xxxx-xxxx-xxxx-xxxx" -U
~/dev/get-clear/scripts/sync-secrets
```

---

## Tokens by machine

| Machine | Token name | Notes |
|---|---|---|
| Home Mac | `get-clear-home` | |
| Work Mac | `get-clear-work` | |

Revoke individual tokens at Fastmail → Settings → Privacy & Security → API tokens.
