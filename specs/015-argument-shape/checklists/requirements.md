# Specification Quality Checklist: Suite Argument Shape and Quoting Rule

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-08-31
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
  - Describes the current `parseOptions` behavior (join-then-split, consume-to-end) only where it is the defect being fixed. FR-021 asserts "a real parser, not a patch" as a requirement without prescribing the design.
- [x] Focused on user value and business needs — one predictable mental model
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded — Phase 1 = reminders + docs; Phase 2 = other four tools
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

Decisions locked with Ken 2026-08-31 (recorded in spec):

- List keyword: **`list` only**.
- Bare leading date: **kept**.
- Scope: **Phase 1 = reminders + design.md + constitution; Phase 2 = calendar/contacts/mail/text, one issue each**.
- Strictness (FR-005..FR-007): **reminders only in Phase 1**, other tools in their Phase 2 issues.
- Old bare-list form: **hard cut**, errors immediately.
- Date introducer: **`due` / `date` + optional `on` filler**; bare leading date still valid.
- Parser: **rebuilt properly (FR-021)**, not patched.

Resolved during `/speckit.plan` (see plan.md / research.md / data-model.md):

1. **Parser location** — GetClearKit `CommandArguments.swift`, tool-agnostic (FR-022).
2. **Descriptor shape** — `CommandShape { identifiers: [Identifier], leading: LeadingRegion, keywords: [Keyword], trailingTextKeyword: String? }`. `Identifier` carries a `required` flag (for `list`'s optional filter). `LeadingRegion` = `.none | .bareDate | .freeText(String)` — collapses "bare date", "quoted name", and "free-text query" into one axis. Took three iterations with Ken.
3. **Naming rule** — an identifier is exactly one token, quoted if spaced. No greedy-to-keyword. Stray token → `unexpectedTokens` + "quote it?" hint. `find`'s query is `.freeText` (whole tail, no quotes).
4. **Trailing text** — parser stops tokenizing at `trailingTextKeyword`, joins the rest; later keywords are literal.
5. **Command scope — 8** (locked with Ken): `add`, `change`, `rename`, `remove`, `done`, `show`, `list`, `find`. `what` excluded (leaving RemindersLib via #40; existence questioned by #197). `lists`/`open` — nullary; stray-token guard deferred (needs plumbing, harmless today).
6. **`design.md` / constitution text** — drafted in `contracts/doc-argument-shape.md`, finalized in Step 8.
7. **SC-006 doc sweep** — `design.md`, `README.md`, `PROMPTS.md`, `UsageText.swift`; manual pass over every reminders `add|change|rename|remove|done|show|list|find` example (Step 8).

Phase 2 migration issues filed: #192 calendar, #193 contacts, #194 mail, #195 text.
Related issues filed this planning pass: #197 (consolidate `what` to `get-clear`).
