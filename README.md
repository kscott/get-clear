# Get Clear

Five tools for macOS. Claude as the conductor.

→ [The longer story](why.md)

---

## Built for people with commitments

The manager who ends the day wondering if anything slipped. The collaborator who made ten promises this week and is holding all of them in their head. The person who wants their word to mean something, and whose follow-ups have follow-ups.

You say what needs to happen. Get Clear handles the rest.

---

## Five tools, one vocabulary

| Tool | What it does |
|---|---|
| [**Contacts**](https://github.com/kscott/contacts-cli) | The people you've committed to |
| [**Reminders**](https://github.com/kscott/reminders-cli) | The promises you can't afford to forget |
| [**Calendar**](https://github.com/kscott/calendar-cli) | When you said you'd be there |
| [**Mail**](https://github.com/kscott/mail-cli) | The thing you said you'd send |
| [**Messages**](https://github.com/kscott/sms-cli) | The quick word |

`add` · `find` · `show` · `change` · `rename` · `remove` — six words across all five tools. Use one, know them all.

---

## The work

**The follow-up you almost forgot**
> "Remind me to follow up with Sarah if I haven't heard from her by Friday afternoon"

```
reminders add "Follow up with Sarah" friday 3pm note "if she hasn't responded"
```
```
Added: Follow up with Sarah (in Work) · due Friday 3:00pm + note
```

Nothing slipped. You never left the room.

**The meeting you just promised**
> "Add a 30-minute check-in with Marcus next Tuesday at 2pm"

```
calendar add "Check-in with Marcus" tuesday 2pm to 2:30pm
```
```
Added: Check-in with Marcus · Tuesday March 31 · 2:00–2:30pm
```

You kept your word in under ten seconds.

**Before a big week**
> "What does my week look like? Show me just work stuff."

```
calendar work week
```
```
Monday Mar 30
  9:00am  Team standup
  1:00pm  Product review

Tuesday Mar 31
  2:00pm  Check-in with Marcus

Wednesday Apr 1
  10:00am  Sprint planning
  3:00pm  1:1 with Jordan

Thursday Apr 2
  11:00am  Recommender models sync
```

Not an app to configure. Just the answer.

**The email with the file**
> "Send Sarah the budget proposal"

You don't remember her address.

```
contacts show "Sarah Okafor"
```
```
Sarah Okafor
  Email    sarah.okafor@company.com (work)
  Phone    720.555.0142
```
```
mail send sarah.okafor@company.com subject "Budget proposal" attach ~/Documents/budget-proposal.pdf body "Sarah, here's the doc we discussed. Let me know if you have questions."
```
```
Sent: Budget proposal → sarah.okafor@company.com (+ 1 attachment)
```

Name to inbox in one motion.

**The quick word**
> "Text Marcus I'm running a few minutes late"

```
sms send Marcus "Running a few minutes late, be right there"
```
```
Sent → Marcus Reyes
```

Done before you're through the door.

**At the end of the day**
> "What did I actually get done today?"

```
get-clear recap
```
```
Thursday March 19 · 9:00am → 4:45pm

  Calendar     Team standup · Sprint planning
  Completed    Follow up with Sarah · Review PR · Call Marcus
  Sent         Email to Alex · Text to Marcus
```

Everything you did. Everything you sent. Everything you kept.

---

## Two ways in

**With Claude** — describe what you need in plain language. Claude figures out the command.

**Directly** — type the command. `reminders add "Call Sarah" friday priority high` is readable enough to run from memory. Fast, precise, no AI in the loop.

Both work. Neither is a workaround for the other.

---

## Install

Signed, notarized, double-click to install:

[Download get-clear.pkg](https://github.com/kscott/get-clear/releases/latest/download/get-clear.pkg)

Tab completion is included — commands, list names, and calendar subsets.

---

## Setup

**Permissions** — on first use, each tool will ask for access to the relevant app. Just approve the prompt.

| Tool | First-run prompt |
|---|---|
| `reminders list` | Reminders access |
| `calendar today` | Calendar access |
| `contacts lists` | Contacts access |
| `sms open` | Messages automation |

**Mail** — run setup once for your provider:

**Gmail:**
```
mail setup gmail
```
Opens a browser to authorize access. Takes about a minute.

**Fastmail:**
```
mail setup fastmail <your-token>
```
[Generate a token here](https://app.fastmail.com/settings/security/tokens/new) with read/write access to Mail.

**Calendar subsets** — name groups of calendars so you can filter by context:

```
calendar setup
```

This walks you through creating a config file. After setup, `calendar work today` shows only your work calendars.

---

## Uninstall

```bash
/usr/local/share/get-clear/uninstall.sh
```

Removes all five tools and prompts to clean up config and credentials.

---

## Requirements

- macOS 14 (Sonoma) or later
- [Claude Code](https://claude.ai/code)
- Fastmail or Gmail account for `mail`

---

## Feedback

[github.com/kscott/get-clear/issues](https://github.com/kscott/get-clear/issues)

---

*Get clear. Stay clear. Prove it.*
