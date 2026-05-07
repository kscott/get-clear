---
description: Cross-repo design critique. Launches broad exploratory agents to surface patterns, design weaknesses, and missing abstractions across the full suite — using recent changes as orientation, not as a search target.
---

## Outline

Run `git diff HEAD~1..HEAD --name-only` to identify which areas of the codebase were recently touched. Use those areas to orient the agents — not to constrain them. The agents explore the full suite. They are looking for what the recent work makes you wonder about, not for things similar to the recent work.

Launch three agents in parallel.

---

### Agent 1 — Cross-suite pattern survey

Prompt:

```
You are doing a design review of the Get Clear monorepo — five Swift CLI tools (reminders-cli, calendar-cli, contacts-cli, mail-cli, text-cli) plus GetClearKit, ContactKit, and AppleEventKitSupport.

Recent work touched these areas: $RECENT_FILES

Do NOT review that work. Do NOT look for things similar to it. Use it only to orient yourself to a corner of the codebase — then step back and survey broadly.

Your questions:
- What concepts appear in multiple tools without a shared abstraction? (Functions doing the same job in different files, types carrying the same data with different names.)
- What parameter groups travel together across multiple functions without a struct to hold them?
- What implicit concepts exist in the code that no type or function is named after?
- What code lives at the wrong layer — logic in a boundary file, or framework-awareness in a Lib?
- Where would introducing a new type, protocol, or function make two or more things simpler or remove a seam that currently requires coordination?

The most valuable finding is not a problem — it is an unnamed concept that wants to become a type or protocol. Look for the shape of that thing. What would you call it? What would it own? Who would depend on it?

Do not look for bugs. Do not look for copies of what was recently changed. Look for patterns that suggest something is trying to become a named concept but hasn't been given one yet.

Read broadly. Search across all five tools. Report the most interesting findings — prioritize unexpected connections over obvious ones.
```

---

### Agent 2 — Boundary and Lib health

Prompt:

```
You are auditing the framework boundary files and Lib targets in the Get Clear monorepo.

Boundary targets to survey: RemindersEventKit, CalendarEventKit, MailJMAP, TextMessages, AppleContactKit, AppleEventKitSupport.
Lib targets to survey: RemindersLib, CalendarLib, ContactsLib, MailLib, TextLib, ContactKit, GetClearKit.

Survey ALL of them — not just recently changed files.

In the boundary files, look for:
- Private functions whose signatures contain no framework types (EK*, CN*, JMAP*) — these are pure functions stranded at the wrong layer
- Logic that would be testable if it lived in the corresponding Lib
- Concepts the boundary knows how to handle that the Lib has no name for

In the Lib files, look for:
- Functions that seem to do more than one thing
- Types that carry data that doesn't belong together
- The same concept expressed differently in two different tools
- Anything that looks like it belongs in GetClearKit or a shared target but doesn't

Report findings as design signals. Note where the same issue appears in multiple places.
```

---

### Agent 3 — Test coverage as a design signal

Prompt:

```
You are surveying the test targets in the Get Clear monorepo to find design signals — not to report a coverage number.

Survey all test targets: RemindersLibTests, CalendarLibTests, ContactsLibTests, MailLibTests, TextLibTests, ContactKitTests, GetClearKitTests, AppleEventKitSupportTests.

Look for:
- Source files in Lib targets with no corresponding test file
- Functions or branches that appear structurally difficult to test (complex setup, many dependencies, side effects mixed with decisions)
- Test files that test more than one source file's worth of behavior
- Patterns in what is NOT tested — are the gaps clustered around a particular kind of logic?

When code is hard to test, that is usually a design signal: the code may be in the wrong layer, have the wrong interface, or be doing two jobs. Report those signals, not just the gaps.
```

---

## After agents complete

Aggregate findings. For each finding:
- State what was found and where
- State what design question it raises
- If it warrants action, say so — but do not implement without Ken's direction

Present findings as a conversation, not a task list. The goal is to surface things worth discussing, not to produce a backlog.
