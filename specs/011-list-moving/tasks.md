# Tasks: List Moving (Reminders)

All tasks complete. Shipped 2026-03-16. Closes reminders-cli #13.

---

- [x] **T001** — Add `list: String` field to `ParsedOptions` in `OptionsParsing.swift`
- [x] **T002** — Add `"list"` to keyword table in `parseOptions` (same pattern as `repeat`, `priority`, `url`)
- [x] **T003** — Implement list move in `change` handler: look up target calendar case-insensitively; fail if not found; set `reminder.calendar`
- [x] **T004** — Add `"list → <from> → <to>"` to change confirmation output
- [x] **T005** — Update `nothing to change` error message to include `list`
- [x] **T006** — Verify combination with other keywords works: `change "title" date friday list Ibotta`
- [x] **T007** — Add 20 tests: basic move, source-list disambiguation, not-found error, combined list+date, error message update
- [x] **T008** — Update MCP server: add `target_list` typed parameter to `reminders_change` tool (commit 533d77f)
- [x] **T009** — Close reminders-cli #13

---

## Closed issues

- [x] **reminders-cli #13** — list moving via `change list <target>`
