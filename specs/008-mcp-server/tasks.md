# Tasks: MCP Server

All tasks complete. Shipped 2026-03-16. Closed get-clear #3.

---

## Server implementation

- [x] **T001** — Create `mcp/server.py` — Python MCP server using `mcp` library
- [x] **T002** — `find_binary()` — resolve binary from PATH then `~/bin`/`~/.local/bin`; raise with install instructions if missing
- [x] **T003** — `strip_ansi()` — strip ANSI codes from all CLI output before returning to Claude
- [x] **T004** — `run()` — execute binary, return stripped output or `"Error: ..."` on non-zero exit; return `"(done)"` for empty success

---

## Tool definitions (22 tools)

- [x] **T005** — Reminders: `reminders_list`, `reminders_find`, `reminders_show`, `reminders_add`, `reminders_change`, `reminders_rename`, `reminders_done`, `reminders_remove`
- [x] **T006** — Calendar: `calendar_list`, `calendar_find`, `calendar_show`, `calendar_add`, `calendar_remove`
- [x] **T007** — Contacts: `contacts_find`, `contacts_show`, `contacts_add`, `contacts_change`
- [x] **T008** — Mail: `mail_send`, `mail_find`
- [x] **T009** — SMS: `sms_send`

---

## Tool description contracts

- [x] **T010** — `reminders_show`, `reminders_change`, `reminders_rename`, `reminders_done`, `reminders_remove`: add "use reminders_find first; always call show before acting" to descriptions
- [x] **T011** — `mail_send`, `sms_send`: add "present full content to user before sending" requirement to descriptions
- [x] **T012** — `mail_send`: document that `cc` and `attach` are repeatable

---

## Safety additions (post-initial-ship)

- [x] **T013** — Add `show-before-act` requirement for calendar remove and contacts change (commit 1d21e66)
- [x] **T014** — Add pre-send confirmation requirement for mail and SMS (commit 8f48171)
- [x] **T015** — Include attachments in mail pre-send confirmation display (commit 044e253)
- [x] **T016** — Enrich all tool descriptions with agent sequencing guidance (commit 2b30b20)

---

## List moving support

- [x] **T017** — Add `target_list` param to `reminders_change` MCP tool (commit 533d77f, after spec 011 shipped)

---

## Packaging and registration

- [x] **T018** — `mcp/pyproject.toml` — hatchling build backend, `mcp` dependency
- [x] **T019** — Fix pyproject.toml — add missing `hatchling` build config (commit c697a3f, diagnosed on work Mac setup)
- [x] **T020** — `mcp/README.md` — setup guide: prerequisites, 3-step install, verify, update, troubleshoot
- [x] **T021** — Register with Claude Code: `claude mcp add get-clear -- uv run .../server.py`
- [x] **T022** — Update `setup.md` with MCP registration as numbered step
- [x] **T023** — Update `going-live.md`: MCP checked off
- [x] **T024** — Live test: confirmed all 22 tools load after session restart; `reminders_add`, `reminders_change`, `reminders_find` all working

---

## Closed issues

- [x] **get-clear #3** — MCP server
