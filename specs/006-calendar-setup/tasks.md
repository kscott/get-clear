# Tasks: Calendar Setup Command

All tasks complete. Shipped 2026-03-15.

---

- [x] **T001** — Implement `calendar setup` command in calendar-cli
- [x] **T002** — Query all available EventKit calendars for display
- [x] **T003** — Render numbered list with ANSI true-color dots (`\x1b[38;2;R;G;Bm●`) from `EKCalendar.cgColor`
- [x] **T004** — Accept selection by number or calendar name (case-insensitive)
- [x] **T005** — Write `~/.config/calendar-cli/config.toml` with selected calendars
- [x] **T006** — Print confirmation of saved calendars before exit
- [x] **T007** — Verify idempotency: re-running setup overwrites config correctly
- [x] **T008** — Document in session log; pattern noted for reuse in `get-clear setup`
