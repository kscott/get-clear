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

## 5. LaunchAgent (daily auto-update)

Pulls all repos and rebuilds any tool that changed. Runs daily at 9am.

```bash
cp ~/dotfiles/launchagents/com.kenscott.git-pull.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.kenscott.git-pull.plist
```

---

## 6. First-run permissions

Each tool will prompt for macOS permissions on first use. Just approve them:

- **Reminders** — `reminders list`
- **Calendar** — `calendar today`
- **Contacts** — `contacts lists`
- **Messages** (Automation) — `sms open`
- **Mail** — handled by JMAP token, no system permission needed

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

## Tokens by machine

| Machine | Token name | Notes |
|---|---|---|
| Home Mac | `get-clear-home` | |
| Work Mac | `get-clear-work` | |

Revoke individual tokens at Fastmail → Settings → Privacy & Security → API tokens.
