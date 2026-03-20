# Feature Specification: MCP Server

**Feature Branch**: `main` (commit de8aeb2 and subsequent, 2026-03-16; get-clear #3)
**Created**: 2026-03-16
**Status**: Shipped (2026-03-16; registered with Claude Code via `claude mcp add`; 22 tools live)
**Input**: Claude could use the Get Clear tools by constructing CLI strings and running them via Bash — but this required exact string construction, was fragile (the `due friday` bug class), and gave Claude no structured parameter contract. An MCP server gives Claude typed input schemas, tool descriptions with sequencing guidance, and output it can parse without ANSI stripping. The result: Claude can add a reminder, find a contact, and send a mail as confidently as a user would.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Claude adds a reminder without string construction (Priority: P1)

The user says "remind me to review the PRD on Friday at 3pm." Claude calls `reminders_add` with `title="Review the PRD"`, `date="friday at 3pm"`. The MCP server shells out to `reminders add "Review the PRD" friday at 3pm` and returns the confirmation. The reminder appears in Reminders.app. Claude never had to construct a quoted shell string with an embedded date.

**Why this priority**: The `due` keyword bug (Claude writing `due friday at 9am` in the CLI string, which broke parsing) was the primary motivation for the MCP server. Typed parameters eliminate the entire class of "Claude put the wrong prefix on the date argument" bugs.

**Independent Test**: In Claude Code with the MCP server registered, ask Claude to add a reminder for a specific date and time. Verify the reminder appears in Reminders.app with the correct due date.

**Acceptance Scenarios**:

1. **Given** a user request with a natural date ("next Tuesday at 2pm"), **When** Claude calls `reminders_add`, **Then** the reminder appears in Reminders.app with the correct due date — no shell-string construction required.
2. **Given** `reminders_add` is called with only `title`, **When** the server runs, **Then** a reminder with no due date is created — all non-required fields are optional.
3. **Given** `reminders_add` is called with `list="Personal"`, **When** the server runs, **Then** the reminder appears in the Personal list, not the default list.

---

### User Story 2 — Claude finds and then acts, with confirmation (Priority: P1)

The user says "mark 'Review the PRD' done." Claude calls `reminders_find` to search, then `reminders_show` to confirm the exact title, then `reminders_done` with the confirmed title. The `reminders_show` step is required before any destructive operation — the tool description says so explicitly. This prevents Claude from acting on a partial match.

**Why this priority**: Reminders, calendar events, and contacts have case-insensitive exact-match requirements. A fuzzy find followed by an immediate action is a mistake waiting to happen. The tool descriptions build the show-before-act contract into Claude's behavior.

**Independent Test**: Ask Claude to mark a reminder done that has a similar name to another reminder. Verify Claude calls `reminders_show` before `reminders_done` — it should not skip the confirmation step.

**Acceptance Scenarios**:

1. **Given** a `reminders_done` call, **When** Claude is following the tool description contract, **Then** `reminders_show` was called first to confirm the exact title.
2. **Given** multiple reminders with similar names, **When** Claude calls `reminders_find`, **Then** the results allow it to distinguish and select the correct one before acting.
3. **Given** a destructive operation (remove, rename, done), **When** the MCP server executes it, **Then** the output confirms what was changed.

---

### User Story 3 — Mail and SMS require pre-send confirmation (Priority: P1)

The user says "send an email to Ann about the meeting." Claude drafts the email and calls `mail_show` before `mail_send`, displaying the To, Subject, and Body for the user to confirm. Only after confirmation does Claude call `mail_send`. The same applies to `sms_send`.

**Why this priority**: Sending a message is irreversible. Unlike a reminder that can be removed or a calendar event that can be deleted, a sent email or SMS cannot be unsent. The pre-send confirmation step is a safety boundary — the user must see what will be sent before it goes.

**Independent Test**: Ask Claude to send an email. Verify that Claude displays the full email content (To, Subject, Body, any attachments) before calling `mail_send`. Deny the send and verify Claude does not attempt to send.

**Acceptance Scenarios**:

1. **Given** a send request, **When** Claude follows the tool description contract, **Then** it presents the full message content (including attachments) before calling `mail_send` or `sms_send`.
2. **Given** the user denies confirmation, **When** Claude receives the denial, **Then** it does not call `mail_send` — the message is not sent.
3. **Given** `mail_send` is called with `attach`, **When** the server runs, **Then** the attachment path is passed to the `mail send` binary correctly.

---

### Edge Cases

**ANSI codes must be stripped from CLI output**
The five CLI tools produce ANSI-colored output. Claude's context receives this as literal escape sequences (`\x1b[1m`) unless they are stripped. The MCP server strips ANSI codes from all command output before returning it to Claude. Without this, Claude would see garbled text and might misparse reminder titles.

**Binary resolution**
The server must find the installed binaries. It checks `PATH` first (via `shutil.which`), then falls back to `~/bin` and `~/.local/bin` (the two common install locations). If a binary isn't found, it returns a clear error message with install instructions rather than a Python exception.

**`(done)` for empty output**
Some commands (e.g., `reminders done`) produce no stdout on success — they just exit 0. The server returns `"(done)"` for empty successful output so Claude has an explicit confirmation to report rather than an empty string.

**`target_list` parameter for list moving**
After `reminders change` gained list-moving support (spec 011), the MCP server was updated to add `target_list` as a typed parameter to `reminders_change`. This is a concrete example of how typed MCP parameters expose new capabilities as they ship.

**The `due` keyword bug class is eliminated**
Before the MCP server, Claude would construct shell strings like `reminders change "title" due friday at 9am`. The `due` keyword was not a recognized token in `parseOptions`, causing it to corrupt the date string. With typed MCP parameters, Claude passes `date="friday at 9am"` directly — no keyword prefix, no ambiguity.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The MCP server MUST expose all operations from all five tools as named MCP tools with typed `inputSchema` parameters.
- **FR-002**: The server MUST shell out to the installed Get Clear binaries — it MUST NOT reimplement any tool logic in Python.
- **FR-003**: Binary resolution MUST check PATH first, then `~/bin` and `~/.local/bin`. A missing binary MUST return a clear error with install instructions, not a Python exception.
- **FR-004**: All CLI output MUST have ANSI codes stripped before being returned as MCP tool output.
- **FR-005**: Empty successful output (exit 0, no stdout) MUST return `"(done)"`.
- **FR-006**: Non-zero exit MUST return an error string prefixed with `"Error: "` containing the CLI's stderr (or stdout if stderr is empty).
- **FR-007**: Tool descriptions for `reminders_show`, `reminders_change`, `reminders_rename`, `reminders_done`, `reminders_remove` MUST include guidance to call `reminders_find` first to locate the reminder, then `reminders_show` to confirm the exact title.
- **FR-008**: Tool descriptions for `mail_send` and `sms_send` MUST require pre-send confirmation — Claude MUST show content to the user before sending.
- **FR-009**: `mail_send` description MUST specify that `cc` and `attach` are repeatable (comma-separated or multiple calls).
- **FR-010**: The MCP server MUST be registered with Claude Code via `claude mcp add get-clear -- uv run /path/to/server.py`.
- **FR-011**: `mcp/README.md` MUST document prerequisites, 3-step install, verify, update, and troubleshoot.
- **FR-012**: `setup.md` MUST include MCP registration as a numbered step in the machine setup guide.

### Key Entities

- **`mcp/server.py`**: Python MCP server. Uses `mcp` library. Registers 22 tools. Shells out to binaries via `subprocess.run`.
- **`find_binary(name: str) -> str`**: Resolves binary path from PATH then `~/bin`/`~/.local/bin`. Raises `FileNotFoundError` with install instructions.
- **`strip_ansi(text: str) -> str`**: Strips ANSI codes via regex `r'\x1b\[[0-9;]*m'`.
- **`run(binary: str, *args: str) -> str`**: Executes binary, returns stripped output or `"Error: ..."`.
- **`TOOLS`**: List of `types.Tool` definitions — 22 tools across all five CLIs.
- **`mcp/pyproject.toml`**: Python package config with `hatchling` build backend and `mcp` dependency.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After `claude mcp add`, all 22 tools appear when Claude lists available MCP tools.
- **SC-002**: A reminder added via `reminders_add` appears in Reminders.app with the correct date and list.
- **SC-003**: Claude calls `reminders_show` before `reminders_done` — confirmed by session observation.
- **SC-004**: A mail sent via `mail_send` is delivered to the recipient — confirmed by checking the recipient's inbox.
- **SC-005**: No ANSI codes appear in MCP tool output — verified by inspecting tool return values in Claude's context.
- **SC-006**: `reminders_add` with `date="friday at 9am"` creates a reminder due Friday at 9am — no `due` prefix bug.

## Design Notes

**Shells out, does not reimplement.** The MCP server is a thin adapter. All business logic — date parsing, EventKit interaction, JMAP calls, osascript — lives in the Swift and existing tool binaries. The server's job is parameter translation and output normalization. This is intentional: if the MCP server reimplemented logic, it would diverge from the CLIs over time.

**Typed parameters are the point.** The primary value of the MCP server over raw Bash tool calls is the typed input schema. Claude no longer constructs shell strings with embedded date values and keyword prefixes. Each parameter is a named field with a type and description. This eliminates the entire `due keyword` bug class.

**Tool descriptions as agent contracts.** The `description` field in each tool definition is not documentation — it is a behavioral contract. Phrases like "Always call this before change, rename, done, or remove" and "present the full message content to the user before calling mail_send" are instructions to Claude's reasoning loop. They work because Claude treats tool descriptions as authoritative guidance.

**22 tools, not 5.** Each tool exposes multiple operations — `reminders_list`, `reminders_find`, `reminders_show`, `reminders_add`, `reminders_change`, `reminders_rename`, `reminders_done`, `reminders_remove` (8 for reminders alone). The granularity is intentional: one tool per operation means Claude's tool-use trace is readable and each call has a clear purpose.

**uv for dependency management.** The server uses `uv` (not pip or poetry) for dependency management. `uv sync` creates a `.venv` from `pyproject.toml`. This matches the modern Python tooling preference in the Get Clear ecosystem and is what `claude mcp add` calls.

## Assumptions

- The MCP server requires `uv` to be installed. If `uv` is not present, `claude mcp add -- uv run ...` fails with a clear error.
- The `mcp` Python library provides the `Server`, `stdio_server`, and `types.Tool` APIs used by the server.
- `subprocess.run` with `capture_output=True` is sufficient for all tool calls — no streaming, no interactive input.
- The server runs in the same user session as Claude Code, so it has access to the same Keychain credentials, contacts database, and calendar database as the user.
