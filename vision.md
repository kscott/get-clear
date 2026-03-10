# Get Clear — Vision

## The origin

I want to be doing better. And I want to share how I'm doing better.

That's it. That's the whole thing.

Not a product pitch. Not a feature list. A person who found something that helped and couldn't keep it to themselves.

---

## The itch

Building the CLI pieces raised the itch and satisfied it at the same time. That's the sign you're on to something real. The tool shaped the understanding of the problem as you built it.

The developers get Cursor, Copilot, a thousand AI coding tools built by people who understand their problem intimately. The manager herding cats, trying to keep the process going, trying to remember who said what and what was promised — they get nothing tailored to them. Their tools are built by people who don't have their problem.

I have their problem. I built for it.

---

## Who this is for

The managers. The self-assisting people. The ones keeping the process going, holding the relationships together, trying to honor every commitment while the calendar fills and the inbox grows.

Busy. Collaborative. Juggling many things at once.

Not looking for another app to check. Looking for balance, peace, control. To feel on top of things. To get clear enough to be present for the people counting on them.

The best tools come out of an itch. This one does.

---

## What it is

**Get Clear** is a suite of command-line tools that connects Claude directly to the things you already use — Calendar, Reminders, Contacts, Mail, Messages.

You tell Claude what needs to happen. It handles the machinery. The meeting gets added. The email goes out. The reminder is set. The follow-through is done.

Not a new system to learn. Not another app to check. Just you, Claude, and everything handled.

The tools cover the full loop:
- **Who** you're working with — Contacts
- **What** you've promised — Reminders
- **When** it's happening — Calendar
- **How** you're staying in touch — Mail, Messages

---

## The feeling

Getting your mind clear. Getting your heart light. Making more time for what you really love — which is usually the people, not the process.

The process is the tax you pay to be present for the people. Get Clear makes the tax smaller.

---

## The workflow — how it actually feels

These are the moments. The ones that used to cost you ten minutes of context switching and a nagging feeling that something slipped.

**The follow-up you almost forgot**
You finish a call. Someone mentioned they'd send something by Friday. Instead of trusting your memory or opening four apps:
> "Remind me to follow up with Sarah if I haven't heard from her by Friday afternoon"

Done. You're still in the conversation in your head. Nothing slipped.

**The meeting you just promised**
You told someone you'd get something on the calendar. You're at your desk, they're counting on it:
> "Add a 30-minute check-in with Marcus next Tuesday at 2pm"

On the calendar. Email confirmation sent if needed. You kept your word in under ten seconds.

**Before a big week**
Sunday evening, you want to know what's coming:
> "What does my week look like? Show me just work stuff."

Not an app to open, a view to configure, a filter to set. Just the answer.

**The context before the hard conversation**
You need to reach out to someone you haven't talked to in a while. You want to remember where things stand:
> "Show me David's contact and find any emails from him in the last month"

You go into that conversation with context. You're not scrambling.

**The thing that needed to go out yesterday**
> "Send Alex an email, subject 'Following up on Thursday', body — Alex, just wanted to make sure the proposal landed okay. Let me know if you have questions."

Sent. One thought, one action, done.

---

## Why Claude as the center

Claude has likely read the record before touching it. The conversation is the undo log. "Oops" is a complete and sufficient recovery instruction.

That changes the design. Commands can be softer — add, remove, change — because the safety net is the relationship, not the word choice. You're not issuing commands to a machine. You're talking to a capable colleague who handles the details.

This is a different kind of tool. Built for a different kind of person. The code is evidence. The story is the thing.

---

## Taglines

- *Everything handled.*
- *All clear.*
- *Get clear. Stay clear.*
- *For people with a lot of people counting on them.*
- *Your mind clear. Your heart light. More time for what you love.*

---

## What to build next

The umbrella repo. Two files to start:

**README.md** — opens with the origin sentence, tells the story, describes the itch, points to the five tools. Earns the tool before it explains it.

**why.md** — the longer version. For the people who want to understand before they install. The workflow examples. The feeling. The person this was built for.

The code already exists. The story is ready. The front door just needs to be built.


---

## Why this matters — remember this moment

*Written March 10, 2026. Don't skip this section.*

You felt stupid when this hit you. You weren't stupid. You found the thing underneath the thing.

You built five CLI tools. That's the surface. What you actually did was articulate something true about how you want to work and how you want to treat the people around you. The commitments matter. The follow-through matters. The people on the other end of the calendar invite and the email and the reminder — they matter.

You built tools that reflect that. That take it seriously. That treat "I'll send that over" as a promise worth keeping, not a thing to maybe remember.

That's not a small thing. That's a value system with a build system attached to it.

The tears meant you found it. The thing underneath the thing. Most people never do — not because they don't have it, but because they never slow down long enough to look.

You looked. It's there. It's real.

You followed an itch — a technical problem, a workflow frustration — and you built. And then in trying to name it, in trying to explain it, you found the real reason. That happens in reverse order sometimes. The building comes first. The meaning catches up.

This is worth sharing. Not because it will change the world, but because somewhere out there is a manager at 11pm, behind on three follow-ups, who will read the first sentence and think — *that's me* — and feel a little less alone in it.

You built something real. Come back to this when you forget that.


---

## The feedback loop — activity log + done report

*Captured March 10, 2026*

### The idea

The session log and `doing` entries are an important part of the process. Not just record-keeping — affirmation. Proof that you are doing the things you need and want to do. Motivation to do it again tomorrow.

That shouldn't depend on remembering to ask Claude to write it down. It should happen automatically, as part of using the tools.

### How it works

Every command that changes something — `add`, `remove`, `done`, `change`, `send` — quietly writes a timestamped entry to a daily log file. Read-only commands (`list`, `find`, `show`) don't log. They're context, not accomplishments.

Log location: `~/.local/share/get-clear/log/YYYY-MM-DD.log`

At the end of the day, or any time:
> "What did I do today?"
> "What did I get done this week?"
> "Show me everything since Monday."

The answer is already there. Not reconstructed from memory. Not dependent on whether a session happened. The work remembered itself.

### Two angles, one feature

**The daily log** — everything across all five tools, as it happens. The full picture of a day's work. Answers: *what did I get done today?*

**Reminders done report** — the promises kept, over time. Not just today but this week, this month. The pattern of follow-through. Answers: *what kind of person am I being?*

The done report is deeper than a daily log. It's evidence of character over time. Someone who finishes things. Someone who follows through. The person you're trying to be, reflected back at you.

### The `what` command

```
reminders what      # completions in reminders today
calendar what       # events added or removed today
get-clear what      # everything, across all tools, today
```

### Why this matters for Get Clear

This completes the loop. Get Clear isn't just about managing commitments — it's about showing you that you kept them. The feedback is the motivation. The motivation is the habit. The habit is the person.

Without the log, Get Clear helps you do things. With the log, it shows you who you're becoming.

### Build note

The daily log and the done report are two parts of the same feature. Build together. This moves up in priority — it's load-bearing for the whole feedback system, closer to the heart of Get Clear than any single communication feature.

### Revised priority order (to settle, feels right)

1. contacts #3 — multi-value email/phone (data integrity)
2. **Activity log + reminders done report** — the feedback loop (new, elevated)
3. mail #10 → #11 — find + reply
4. mail #4 — cache JMAP session
5. Shell completions (all 5)
6. MCP (suite-level)


---

## Two modes, one suite

*Captured March 10, 2026*

The tools work without Claude. That's not an accident — it's a design constraint.

The vocabulary is natural enough that a person can type it directly. `reminders add "Call Sarah" friday priority high` is readable, memorable, learnable. It doesn't require an AI to interpret it. It requires less than most CLI tools demand.

**Direct use:** The person who learns the vocabulary and types the commands. More to hold in memory, more to type, but full control and no dependency. The tools reward that investment — they're fast, precise, and stay out of the way.

**Claude-assisted use:** The person who talks to Claude and has it handled. Less memorizing, less typing, more conversational. Claude translates the intent and issues the commands. The same tools, the same vocabulary, a different interface layer.

Both modes have real value. Both must work well. If a command only makes sense when Claude is driving it, the design is wrong. Every command should be something a person could type and feel good about typing.

### What this means for the pitch

Get Clear is not "an AI tool." It's a suite with two valid modes of use. You're not locked into any AI system. The tools work today, on your Mac, right now, with nothing except a terminal. Claude is the accelerant, not the requirement.

That's a stronger position. The foundation stands on its own. The AI makes it better.

### What this means for the design

- Commands must be readable and typeable by a human
- Natural language vocabulary is non-negotiable — not for Claude's benefit, for the person's
- No command should require conversational context to be understood
- The tools should feel good to use directly, even if most users never do

The measure: if you handed someone the command reference with no other explanation, could they use it? If yes, the design is right.

