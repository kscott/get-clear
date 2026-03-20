# Tasks: Date Parsing Extensions

All tasks complete. Shipped in two phases: 2026-03-15 (explicit year, US slash) and 2026-03-19 (abbreviated months, closes reminders-cli #16).

---

## Phase 1 — Explicit year and US slash format (2026-03-15)

- [x] **T001** — Add three-component parsing branch: `"month day year"` with full and abbreviated months, comma trimming
- [x] **T002** — Add `"day month year"` order support (e.g., `"10 march 2027"`)
- [x] **T003** — Add US slash format: `"M/D/YYYY"` and `"M/D/YY"` (two-digit year → 2000+)
- [x] **T004** — Add ISO slash/dash format: `"YYYY-MM-DD"` and `"YYYY/MM/DD"`
- [x] **T005** — Add short date: `"M/D"` and `"M-D"` with roll-to-next-year if past
- [x] **T006** — Add disambiguation heuristic: first component > 31 → ISO; ≤ 31 → US
- [x] **T007** — Tests: cover explicit year formats (4-digit and 2-digit), US slash, ISO slash, short date

---

## Phase 2 — Abbreviated months (2026-03-19, reminders-cli #16)

- [x] **T008** — Add 3-letter month abbreviations to months dictionary: jan, feb, mar, apr, jun, jul, aug, sep, oct, nov, dec
- [x] **T009** — Verify `may` already works (it's both full name and abbreviation)
- [x] **T010** — Add 10 tests for abbreviated month formats including the EventKit format `"Mar 20, 2026"`
- [x] **T011** — Verify `get-clear recap` now lists completed reminders correctly
- [x] **T012** — Close reminders-cli #16

---

## Closed issues

- [x] **reminders-cli #16** — abbreviated month names in date parser
