---
description: Pre-plan codebase survey. Run after /speckit.specify, before /speckit.plan. Explores the full suite to surface existing patterns, seams, and abstractions the planner should know about before designing the feature.
handoffs:
  - label: Build Technical Plan
    agent: speckit.plan
    prompt: Create a plan for the spec, informed by the survey findings.
    send: true
---

## Outline

1. Run `.specify/scripts/bash/setup-plan.sh --json` from repo root to get FEATURE_SPEC and BRANCH.

2. Read FEATURE_SPEC to understand the general problem area. Do not treat it as a search query. The spec tells you where to orient — the agents explore from there.

3. Launch two agents in parallel.

---

### Agent 1 — Existing capability landscape

Prompt:

```
You are preparing a technical planner to design a new feature for the Get Clear monorepo. Read the feature spec at $FEATURE_SPEC to understand the general problem area.

Then explore the full monorepo broadly. Your goal is NOT to find things that implement this feature — it does not exist yet. Your goal is to produce a landscape of what already exists that a designer needs to know before committing to an approach.

Look for:
- Types, protocols, and functions that already exist in this problem space
- Patterns that repeat across the five tools that a new feature should follow or extend
- Shared infrastructure (GetClearKit, ContactKit, AppleEventKitSupport) that already handles part of what this feature will need
- Conventions in naming, file structure, and handler design that the new feature must conform to
- Concepts that don't have a name yet but probably should — places where introducing a new type or protocol would make the new feature cleaner and also improve what already exists

The most useful thing you can surface is not just what exists, but what wants to exist — an abstraction that the new feature would need and that would also clean up something already there.

Do not evaluate risk or plan attachment points — that is Agent 2's job. Report what exists, what conventions apply, and what new abstractions the design should consider.
```

---

### Agent 2 — Seams and risk survey

Prompt:

```
You are helping a technical planner understand where a new feature would land in the Get Clear monorepo and what it would disturb. Read the feature spec at $FEATURE_SPEC to understand the general area.

Then survey the full monorepo for:
- Seams in the current design — the specific places where new code would attach, and what shape it must be to fit cleanly
- Existing abstractions that are almost right but not quite — things that would need to be generalized rather than copied, or that could cause duplication if the designer doesn't know they exist
- Tests that would need to change or be extended if this feature lands
- Design decisions in ARCHITECTURE.md or the code that constrain how this feature can be shaped

Do not describe what already exists in general — that is Agent 1's job. Focus on where the feature would land, what it would touch, and what could go wrong if the planner doesn't know about it.
```

---

## After agents complete

Synthesize findings into a brief survey report — what exists that's relevant, what seams the feature will cross, what constraints apply, what the planner should not have to rediscover. Write it to `$FEATURE_DIR/survey.md`.

Present findings to Ken before handing off to `/speckit.plan`.
