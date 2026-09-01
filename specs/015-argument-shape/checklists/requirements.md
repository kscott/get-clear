# Specification Quality Checklist: Suite Argument Shape and Quoting Rule

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-08-31
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
  - Names `parseOptions` behavior descriptively (join-then-split, "consume to end of line") only where it is the defect being fixed. No Swift, no target names, no parser design — those are plan.md.
- [x] Focused on user value and business needs — one predictable mental model across five tools
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded — Out of Scope names `--draft`, new vocabulary, matching behavior
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows (form a command, list assignment, date field, trailing text, usage texts, error on junk)
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- Confirmed with Ken 2026-08-31: `list` keyword required; `due` allowed but not required with a date; note/body/message never needs but allows quotes; double quotes are the documented default.
- Sequencing: lands before #191 (location-alarm vocabulary) and #014 (private-metadata vocabulary).
- Behavioral parsing changes are confined to the reminders tool (FR-008..FR-013) plus the suite-wide "unrecognized token is an error" tightening (FR-005..FR-007). Contacts/mail/text/calendar are audit-and-document only unless the tightening surfaces a token they currently absorb.
- Open for `/speckit.plan`:
  1. Whether the reminders parser stays join-then-regex-split or moves to token-stream parsing to support FR-005..FR-007 cleanly.
  2. Where the shared shape logic lives (GetClearKit vs per-tool) — the constitution's "GetClearKit first" rule applies.
  3. The exact `design.md` section and constitution entry text.
  4. The doc-example extraction check for SC-007.
