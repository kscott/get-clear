#!/usr/bin/env python3
"""
Get Clear MCP Server

Exposes the full Get Clear CLI suite to Claude via MCP.
Shells out to installed binaries — no framework dependencies beyond subprocess.

Install in Claude Code:
    claude mcp add get-clear -- uv run /path/to/get-clear/mcp/server.py

Or with a venv:
    cd ~/dev/get-clear/mcp && uv sync
    claude mcp add get-clear -- uv run ~/dev/get-clear/mcp/server.py
"""

import asyncio
import re
import shutil
import subprocess
from pathlib import Path

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp import types

app = Server("get-clear")


# ── Binary resolution ─────────────────────────────────────────────────────────

def find_binary(name: str) -> str:
    """Find a Get Clear binary, checking PATH then known install locations."""
    if path := shutil.which(name):
        return path
    for prefix in [Path.home() / "bin", Path.home() / ".local" / "bin"]:
        p = prefix / name
        if p.exists():
            return str(p)
    raise FileNotFoundError(
        f"'{name}' not found. Install Get Clear first: https://github.com/kscott/get-clear"
    )


def strip_ansi(text: str) -> str:
    return re.sub(r'\x1b\[[0-9;]*m', '', text)


def run(binary: str, *args: str) -> str:
    """Run a Get Clear binary and return its output."""
    try:
        cmd = [find_binary(binary)] + [a for a in args if a is not None]
        result = subprocess.run(cmd, capture_output=True, text=True)
        output = strip_ansi(result.stdout.strip())
        if result.returncode != 0:
            error = strip_ansi(result.stderr.strip() or result.stdout.strip())
            return f"Error: {error}"
        return output or "(done)"
    except FileNotFoundError as e:
        return f"Error: {e}"


# ── Tool definitions ──────────────────────────────────────────────────────────

TOOLS = [
    # ── Reminders ─────────────────────────────────────────────────────────────
    types.Tool(
        name="reminders_list",
        description="List reminders. Optionally filter by list name and sort order.",
        inputSchema={
            "type": "object",
            "properties": {
                "list": {"type": "string", "description": "List name, e.g. 'Ibotta', 'Personal'"},
                "sort": {
                    "type": "string",
                    "enum": ["due", "priority", "title", "created"],
                    "description": "Sort order (default: due)",
                },
            },
        },
    ),
    types.Tool(
        name="reminders_find",
        description="Search reminders by title or note content using a partial/contains match. Use this to browse or locate a reminder. Before calling change, done, or remove, use reminders_show to get the exact title.",
        inputSchema={
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Search query"},
            },
            "required": ["query"],
        },
    ),
    types.Tool(
        name="reminders_show",
        description="Show full details of a reminder. Requires an exact title (case-insensitive). Use reminders_find first if unsure of the exact title. Always call this before change, rename, done, or remove to confirm you have the right reminder.",
        inputSchema={
            "type": "object",
            "properties": {
                "title": {"type": "string"},
                "list": {"type": "string", "description": "List name to narrow search"},
            },
            "required": ["title"],
        },
    ),
    types.Tool(
        name="reminders_add",
        description="Add a new reminder.",
        inputSchema={
            "type": "object",
            "properties": {
                "title": {"type": "string"},
                "list": {"type": "string", "description": "List name (uses configured default if omitted)"},
                "date": {"type": "string", "description": "Due date, e.g. 'friday', 'march 15', 'tomorrow at 9am'"},
                "repeat": {"type": "string", "description": "Recurrence, e.g. 'weekly', 'monthly', 'every 2 weeks', 'last tuesday'"},
                "priority": {"type": "string", "enum": ["high", "medium", "low"]},
                "url": {"type": "string"},
                "note": {"type": "string"},
            },
            "required": ["title"],
        },
    ),
    types.Tool(
        name="reminders_change",
        description="Update attributes of an existing reminder. Before calling this, use reminders_show and display the current record to the user — this gives them a chance to confirm or cancel before the change is made. Only specified fields are changed; omitted fields are left alone. Use 'none' to clear a field.",
        inputSchema={
            "type": "object",
            "properties": {
                "title": {"type": "string", "description": "Exact reminder title (case-insensitive)"},
                "list": {"type": "string", "description": "List name to narrow search"},
                "date": {"type": "string", "description": "New due date, or 'none' to clear"},
                "repeat": {"type": "string", "description": "New recurrence, or 'none' to clear"},
                "priority": {"type": "string", "enum": ["high", "medium", "low", "none"]},
                "url": {"type": "string", "description": "New URL, or 'none' to clear"},
                "note": {"type": "string", "description": "New note text, or 'none' to clear"},
                "target_list": {"type": "string", "description": "Move reminder to this list"},
            },
            "required": ["title"],
        },
    ),
    types.Tool(
        name="reminders_rename",
        description="Rename a reminder (changes its title).",
        inputSchema={
            "type": "object",
            "properties": {
                "old_title": {"type": "string"},
                "new_title": {"type": "string"},
                "list": {"type": "string"},
            },
            "required": ["old_title", "new_title"],
        },
    ),
    types.Tool(
        name="reminders_done",
        description="Mark a reminder as complete. Requires exact title (case-insensitive). Use reminders_find first if unsure of the exact title.",
        inputSchema={
            "type": "object",
            "properties": {
                "title": {"type": "string"},
                "list": {"type": "string"},
            },
            "required": ["title"],
        },
    ),
    types.Tool(
        name="reminders_remove",
        description="Remove a reminder permanently. Before calling this, use reminders_show and display the full record to the user — this is their only chance to catch a mistake before the reminder is gone. Requires exact title (case-insensitive).",
        inputSchema={
            "type": "object",
            "properties": {
                "title": {"type": "string"},
                "list": {"type": "string"},
            },
            "required": ["title"],
        },
    ),

    # ── Calendar ──────────────────────────────────────────────────────────────
    types.Tool(
        name="calendar_list",
        description="List calendar events for a time range.",
        inputSchema={
            "type": "object",
            "properties": {
                "range": {"type": "string", "description": "Time range: 'today', 'week', '7d', 'march 15 to march 20' (default: today)"},
                "subset": {"type": "string", "description": "Calendar subset name, e.g. 'work', 'personal'"},
            },
        },
    ),
    types.Tool(
        name="calendar_find",
        description="Search calendar events by title.",
        inputSchema={
            "type": "object",
            "properties": {
                "query": {"type": "string"},
                "subset": {"type": "string", "description": "Calendar subset name"},
            },
            "required": ["query"],
        },
    ),
    types.Tool(
        name="calendar_add",
        description="Add a calendar event.",
        inputSchema={
            "type": "object",
            "properties": {
                "title": {"type": "string"},
                "date": {"type": "string", "description": "Date of the event, e.g. 'friday', 'march 20'"},
                "time": {"type": "string", "description": "Time range, e.g. '9am to 10am', '2pm to 3:30pm'"},
            },
            "required": ["title"],
        },
    ),
    types.Tool(
        name="calendar_remove",
        description="Remove a calendar event.",
        inputSchema={
            "type": "object",
            "properties": {
                "title": {"type": "string"},
                "date": {"type": "string", "description": "Date to narrow if multiple events share the title"},
            },
            "required": ["title"],
        },
    ),

    # ── Contacts ──────────────────────────────────────────────────────────────
    types.Tool(
        name="contacts_find",
        description="Search contacts by name, email, or phone. Use for browsing or confirming a contact exists. Before taking any action (send SMS, send email), always follow up with contacts_show to get the full contact record.",
        inputSchema={
            "type": "object",
            "properties": {
                "query": {"type": "string"},
            },
            "required": ["query"],
        },
    ),
    types.Tool(
        name="contacts_show",
        description="Show full details of a contact: all phone numbers, emails, and notes. Always call this before sending a message or email to a contact — it ensures you have the right address. Prefer phone number for SMS; prefer email for mail. Fall back to the other only if one is missing.",
        inputSchema={
            "type": "object",
            "properties": {
                "name": {"type": "string"},
            },
            "required": ["name"],
        },
    ),
    types.Tool(
        name="contacts_add",
        description="Add a new contact.",
        inputSchema={
            "type": "object",
            "properties": {
                "name": {"type": "string"},
                "email": {"type": "string"},
                "phone": {"type": "string"},
                "note": {"type": "string"},
            },
            "required": ["name"],
        },
    ),
    types.Tool(
        name="contacts_change",
        description="Update a contact's attributes. Before calling this, use contacts_show and display the current record to the user — gives them a chance to confirm before the change is made. Use 'none' to clear a field.",
        inputSchema={
            "type": "object",
            "properties": {
                "name": {"type": "string"},
                "email": {"type": "string", "description": "New email, or 'none' to clear"},
                "phone": {"type": "string", "description": "New phone, or 'none' to clear"},
                "note": {"type": "string", "description": "New note, or 'none' to clear"},
            },
            "required": ["name"],
        },
    ),
    types.Tool(
        name="contacts_rename",
        description="Rename a contact.",
        inputSchema={
            "type": "object",
            "properties": {
                "old_name": {"type": "string"},
                "new_name": {"type": "string"},
            },
            "required": ["old_name", "new_name"],
        },
    ),
    types.Tool(
        name="contacts_remove",
        description="Remove a contact permanently. Before calling this, use contacts_show and display the full record to the user — this is their only chance to catch a mistake before the contact is deleted.",
        inputSchema={
            "type": "object",
            "properties": {
                "name": {"type": "string"},
            },
            "required": ["name"],
        },
    ),
    types.Tool(
        name="contacts_export",
        description="Export a contact group as a 'Name <email>' list, ready to paste into mail recipients.",
        inputSchema={
            "type": "object",
            "properties": {
                "group": {"type": "string", "description": "Contact group name"},
            },
            "required": ["group"],
        },
    ),

    # ── Mail ──────────────────────────────────────────────────────────────────
    types.Tool(
        name="mail_send",
        description="Send an email via Fastmail/JMAP. Before sending, display the to address, subject, body, and any attachments to the user and wait for confirmation — email cannot be unsent. If given a contact name rather than an email address, call contacts_show first to confirm their email. Pass the email address directly to this tool.",
        inputSchema={
            "type": "object",
            "properties": {
                "to": {"type": "string", "description": "Email address (preferred) or contact name"},
                "subject": {"type": "string"},
                "body": {"type": "string", "description": "Email body text"},
                "from_identity": {"type": "string", "description": "Sender identity (name or email), uses default if omitted"},
                "cc": {"type": "string", "description": "CC recipient name or email"},
                "attach": {"type": "string", "description": "File path to attach"},
            },
            "required": ["to"],
        },
    ),
    types.Tool(
        name="mail_find",
        description="Search sent mail.",
        inputSchema={
            "type": "object",
            "properties": {
                "query": {"type": "string"},
            },
            "required": ["query"],
        },
    ),

    # ── SMS ───────────────────────────────────────────────────────────────────
    types.Tool(
        name="sms_send",
        description="Send an SMS or iMessage via Messages.app. Before sending, display the recipient and message to the user and wait for confirmation — messages cannot be unsent. If given a contact name, always call contacts_show first to get their phone number. Pass the phone number directly to this tool — do not pass a name or email unless you have confirmed no phone number exists.",
        inputSchema={
            "type": "object",
            "properties": {
                "contact": {"type": "string", "description": "Phone number (preferred), email, or contact name as last resort"},
                "message": {"type": "string"},
            },
            "required": ["contact", "message"],
        },
    ),
]


# ── Tool dispatch ─────────────────────────────────────────────────────────────

def dispatch(name: str, args: dict) -> str:
    # reminders
    if name == "reminders_list":
        parts = ["list"]
        if args.get("list"): parts.append(args["list"])
        if args.get("sort"): parts += ["by", args["sort"]]
        return run("reminders", *parts)

    if name == "reminders_find":
        return run("reminders", "find", args["query"])

    if name == "reminders_show":
        parts = ["show", args["title"]]
        if args.get("list"): parts.append(args["list"])
        return run("reminders", *parts)

    if name == "reminders_add":
        parts = ["add", args["title"]]
        if args.get("list"):     parts.append(args["list"])
        if args.get("date"):     parts.append(args["date"])
        if args.get("repeat"):   parts += ["repeat", args["repeat"]]
        if args.get("priority"): parts.append(args["priority"])
        if args.get("url"):      parts += ["url", args["url"]]
        if args.get("note"):     parts += ["note", args["note"]]  # must be last
        return run("reminders", *parts)

    if name == "reminders_change":
        parts = ["change", args["title"]]
        if args.get("list"):        parts.append(args["list"])
        if args.get("date"):        parts.append(args["date"])
        if args.get("repeat"):      parts += ["repeat", args["repeat"]]
        if args.get("priority"):    parts.append(args["priority"])
        if args.get("url"):         parts += ["url", args["url"]]
        if args.get("target_list"): parts += ["list", args["target_list"]]
        if args.get("note"):        parts += ["note", args["note"]]  # must be last
        return run("reminders", *parts)

    if name == "reminders_rename":
        parts = ["rename", args["old_title"], args["new_title"]]
        if args.get("list"): parts.append(args["list"])
        return run("reminders", *parts)

    if name == "reminders_done":
        parts = ["done", args["title"]]
        if args.get("list"): parts.append(args["list"])
        return run("reminders", *parts)

    if name == "reminders_remove":
        parts = ["remove", args["title"]]
        if args.get("list"): parts.append(args["list"])
        return run("reminders", *parts)

    # calendar
    if name == "calendar_list":
        parts = []
        if args.get("subset"): parts.append(args["subset"])
        parts.append("list")
        parts.append(args.get("range", "today"))
        return run("calendar", *parts)

    if name == "calendar_find":
        parts = []
        if args.get("subset"): parts.append(args["subset"])
        parts += ["find", args["query"]]
        return run("calendar", *parts)

    if name == "calendar_add":
        parts = ["add", args["title"]]
        if args.get("date"): parts.append(args["date"])
        if args.get("time"): parts.append(args["time"])
        return run("calendar", *parts)

    if name == "calendar_remove":
        parts = ["remove", args["title"]]
        if args.get("date"): parts.append(args["date"])
        return run("calendar", *parts)

    # contacts
    if name == "contacts_find":
        return run("contacts", "find", args["query"])

    if name == "contacts_show":
        return run("contacts", "show", args["name"])

    if name == "contacts_add":
        parts = ["add", args["name"]]
        if args.get("email"): parts += ["email", args["email"]]
        if args.get("phone"): parts += ["phone", args["phone"]]
        if args.get("note"):  parts += ["note", args["note"]]  # must be last
        return run("contacts", *parts)

    if name == "contacts_change":
        parts = ["change", args["name"]]
        if args.get("email"): parts += ["email", args["email"]]
        if args.get("phone"): parts += ["phone", args["phone"]]
        if args.get("note"):  parts += ["note", args["note"]]  # must be last
        return run("contacts", *parts)

    if name == "contacts_rename":
        return run("contacts", "rename", args["old_name"], args["new_name"])

    if name == "contacts_remove":
        return run("contacts", "remove", args["name"])

    if name == "contacts_export":
        return run("contacts", "export", args["group"])

    # mail
    if name == "mail_send":
        parts = ["send", args["to"]]
        if args.get("cc"):            parts += ["cc", args["cc"]]
        if args.get("from_identity"): parts += ["from", args["from_identity"]]
        if args.get("subject"):       parts += ["subject", args["subject"]]
        if args.get("attach"):        parts += ["attach", args["attach"]]
        if args.get("body"):          parts += ["body", args["body"]]  # must be last
        return run("mail", *parts)

    if name == "mail_find":
        return run("mail", "find", args["query"])

    # sms
    if name == "sms_send":
        return run("sms", "send", args["contact"], args["message"])

    return f"Error: unknown tool '{name}'"


# ── MCP handlers ──────────────────────────────────────────────────────────────

@app.list_tools()
async def list_tools() -> list[types.Tool]:
    return TOOLS


@app.call_tool()
async def call_tool(name: str, arguments: dict) -> list[types.TextContent]:
    result = dispatch(name, arguments or {})
    return [types.TextContent(type="text", text=result)]


# ── Entry point ───────────────────────────────────────────────────────────────

async def main():
    async with stdio_server() as (read_stream, write_stream):
        await app.run(read_stream, write_stream, app.create_initialization_options())


if __name__ == "__main__":
    asyncio.run(main())
