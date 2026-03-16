# Get Clear — MCP Server

Exposes the full Get Clear suite to Claude via the Model Context Protocol.

Claude can add reminders, check your calendar, look up contacts, send email, and send messages — across tools, in one conversation — without you switching apps or typing CLI commands yourself.

---

## Prerequisites

- **Get Clear installed** — all five tools must be in your PATH (`reminders`, `calendar`, `contacts`, `mail`, `sms`). See [setup.md](../setup.md).
- **Python 3.11+** — comes with macOS 14+. Check: `python3 --version`
- **Claude Code** — the CLI (`claude`)

---

## Setup

### 1. Install Python dependencies

```bash
cd ~/dev/get-clear/mcp
python3 -m venv .venv
.venv/bin/pip install mcp
```

### 2. Register with Claude Code

```bash
claude mcp add get-clear -- ~/dev/get-clear/mcp/.venv/bin/python3 ~/dev/get-clear/mcp/server.py
```

This adds the server to `~/.claude.json`. It takes effect in the next Claude Code session.

### 3. Verify

Start a new Claude Code session and ask:

> "List my reminders"
> "What's on my calendar today?"
> "Find the contact Mary Beth Nagle"

Claude will use the MCP tools directly — no need to construct CLI commands.

---

## What's exposed

| Tool prefix | Commands |
|---|---|
| `reminders_` | `list`, `find`, `show`, `add`, `change`, `rename`, `done`, `remove` |
| `calendar_` | `list`, `find`, `add`, `remove` |
| `contacts_` | `find`, `show`, `add`, `change`, `rename`, `remove`, `export` |
| `mail_` | `send`, `find` |
| `sms_` | `send` |

Tool parameters are typed and named — Claude passes `date: "friday at 9am"` as a structured field, not as a constructed command string. This eliminates the whole class of parsing ambiguity that affects CLI usage.

---

## Updating

The server shells out to the installed binaries, so Get Clear updates automatically pick up new behaviour. No server restart or reinstall needed when you update the CLI tools.

If you update the server itself (`server.py` or dependencies), reinstall deps and re-register:

```bash
cd ~/dev/get-clear/mcp
.venv/bin/pip install --upgrade mcp
claude mcp add get-clear -- ~/dev/get-clear/mcp/.venv/bin/python3 ~/dev/get-clear/mcp/server.py
```

---

## Troubleshooting

**"reminders not found" or similar**
The binary isn't in PATH or `~/bin`. Run `which reminders` to check. If missing, re-run `reminders setup` from the tool repo.

**Tools don't appear in Claude**
Restart the Claude Code session after registering. Run `claude mcp list` to confirm `get-clear` is listed.

**Permission errors on first use**
The underlying CLI tools trigger macOS permission prompts (Reminders, Calendar, Contacts, Messages) on first access. These only appear once — approve them and subsequent calls work silently.
