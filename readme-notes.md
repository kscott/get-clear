# README notes — things to cover

Scratch file. Not the README itself — just things that need to land there.

---

## Must-have sections

### The origin sentence
Lead with it. From vision.md. Don't bury it.

### Who this is for
People with a lot of people counting on them. Not developers. Not power users.
The person who wants to tell Claude "set a reminder, send that email, what's on my calendar today"
and have it just work.

### What it does
Five tools. One sentence each. No jargon.

### Install
- PKG download (primary) — double-click, done
- curl one-liner (alternative)

### Get started (post-install)
- First-run permissions: what prompts will appear, why, just approve them
- Mail setup: get a Fastmail JMAP token, run `mail setup <token>`
- Calendar setup: run `calendar calendars` to see names, create config.toml grouping them

### Tab completion
**Must cover.** The completions install automatically with the PKG.
For the curl install, restart the shell after installing — completions land in
~/.local/share/zsh/site-functions/ and the installer patches .zshrc.

What completes:
- All five tools: commands on first tab
- reminders: list names, reminder titles
- calendar: subset names (from config.toml), commands after subset
- contacts: group names, contact names for show/change/rename/remove
- mail, sms: commands only

Note: zsh only. macOS default since Catalina — covers virtually all users.

---

## Good to have

### The feedback loop (when activity log ships)
"Every action is logged. `reminders what` shows you what you've done."
Load-bearing for the vision — makes it feel like a system, not just tools.

### Uninstall
One line: run the uninstaller. Point to it.
Location after PKG install: /usr/local/share/get-clear/uninstall.sh

### Update notifications (when shipped)
PKG installs check for updates automatically — you'll see a one-line hint
in the terminal when a new version is available. Install the new PKG to update.

---

## Tone notes
- Short sentences
- No "leverage", "seamlessly", "powerful"
- Write like the tools work: direct, no ceremony
- The README is the first impression — don't make someone read three paragraphs
  before they know what the thing does
