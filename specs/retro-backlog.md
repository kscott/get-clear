# Retrospective Spec Backlog

Specs for shipped features that predate the speckit process. Written retrospectively from git diffs, session logs, and source inspection.

---

## Status

| # | Feature | Status |
|---|---------|--------|
| 004 | GetClearKit Shared Infrastructure | ✅ Done |
| 005 | Signing, Notarization & Distribution | ✅ Done |
| 006 | Calendar Setup Command | ✅ Done |
| 007 | Shell Completions | ✅ Done |
| 008 | MCP Server | ✅ Done |
| 009 | Multi-Match Disambiguation | ✅ Done |
| 010 | Date Parsing Extensions | ✅ Done |
| 011 | List Moving (Reminders) | ✅ Done |

---

## Process

For each retrospective spec:
1. Agent reads: relevant git diffs + session log + current source files
2. Agent writes: `spec.md` + `tasks.md` (all [x]) to `specs/00N-feature-name/`
3. Human reviews in Marked 2
4. Spot-fix gaps: missing edge cases, thin user stories, "why not" reasoning
5. Commit alongside any design.md / constitution updates surfaced by review

---

## Not Worth Speccing

- Command vocabulary standardization — in design.md + constitution
- Initial tool implementations (v1.0 of each) — session log too sparse, too foundational
- Bug fixes (JMAP auth, attachments, Sent mailbox routing, CoreData noise) — one-liners, no design
- `open` command wrappers, bare help/version, feedback URLs — trivial
- Cosmetic: stapler removal, note support removal, SQLite removal
