# Tasks: Multi-Match Disambiguation

All tasks complete. Shipped 2026-03-10.

---

- [x] **T001** — Identify commands that require exact match: `show`, `change`, `rename`, `done`, `remove`
- [x] **T002** — Implement multi-match detection: when title lookup returns > 1 result with no list specified, collect all candidates
- [x] **T003** — Output candidate list with title + list name for each match
- [x] **T004** — Include disambiguation suggestion with corrected command syntax (include list name argument)
- [x] **T005** — Exit without performing any action when disambiguation triggers
- [x] **T006** — Verify single-match case still works without prompt
- [x] **T007** — Verify not-found case still shows clear error
