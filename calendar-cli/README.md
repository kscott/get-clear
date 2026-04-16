# calendar-cli

A command-line tool that lets Claude read and query your Apple Calendar — just by asking.

Instead of switching to Calendar.app, you ask Claude what's coming up and it handles it. The tool connects directly to Apple's native Calendar framework, so all your existing calendars — including external ones like Google or Exchange configured in Calendar.app — work exactly as before.

Part of the [Get Clear](https://github.com/kscott/get-clear) suite.

## Using with Claude

> "What's on my calendar this week?"
> "Do I have anything tomorrow afternoon?"
> "What does my week look like — just work stuff?"
> "Show me everything I have in March"
> "Add a team standup tomorrow at 9am"
> "Remove the budget review on Friday"

### Tips for best results

- **Use named subsets** — once you set up a config file, "just work stuff" or "personal only" works naturally
- **Be specific about range** — "this week", "next two weeks", "march 15 to march 20" all work
- **Ask what's next** — "what are my next 5 events" gives a quick at-a-glance view

## Setup

### Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon Mac (arm64) for the pre-built binary; Intel Macs must build from source

### Install

Install the full Get Clear suite via the PKG installer — download from the [latest release](https://github.com/kscott/get-clear/releases/latest) and run it.

This installs all five tools to `/usr/local/bin`. Make sure that's in your `$PATH`:

```bash
export PATH="/usr/local/bin:$PATH"   # add to ~/.zshrc
```

On first run, macOS will prompt you to grant Calendar access.

### Build from source

```bash
xcode-select --install   # if not already installed
git clone https://github.com/kscott/calendar-cli.git ~/dev/calendar-cli
cd ~/dev/calendar-cli
swift build -c release
cp .build/release/calendar-bin /usr/local/bin/calendar
```

## Command reference

```
calendar                                      # Show help
calendar --version                            # Show version
calendar open                                 # Open Calendar.app
calendar calendars                            # List all available calendars
calendar setup                                # Guided config.toml creation
calendar list <range>                         # Events in range
calendar today                                # Today's events
calendar week                                 # This week's events
calendar next [n]                             # Next N events (default 5)
calendar find <query> [range]                 # Find events by title
calendar show <title> [date]                  # Full event detail
calendar add <title> [date] [time to time]    # Add an event
calendar remove <title> [date]                # Remove an event
```

Prefix a subset name to filter by calendar group:

```bash
calendar work today
calendar personal week
calendar work next 5
calendar work find standup
```

### Range formats

| Format | Example |
|--------|---------|
| Relative days | `today`, `tomorrow`, `yesterday` |
| Week spans | `week`, `this week`, `next week`, `last week` |
| Month spans | `month`, `next month`, `last month` |
| Weekday | `monday` … `sunday` |
| Month + day | `march 15` |
| ISO date | `2026-03-15` |
| Short numeric | `3/15` |
| N-day window | `7d`, `30d` |
| Explicit range | `march 15 to march 20` |

### Config file

Create `~/.config/calendar-cli/config.toml` to define named subsets:

```toml
[subsets]
work     = ["Work", "Meetings", "Google Calendar"]
personal = ["Home", "Family", "Doctor Appointments"]
```

Subset names are case-insensitive. Calendar names must match exactly as shown in `calendar calendars`. Run `calendar setup` for a guided setup.

## Known limitations

- `add` creates events in the first calendar of the subset filter, or your default calendar
- `show` and `remove` with multiple matches list candidates and ask you to narrow by date
- External calendars must be configured in Calendar.app to be visible

## Project structure

```
calendar-cli/
├── Package.swift
├── Sources/
│   ├── CalendarLib/                          # Pure Swift — no framework deps, fully testable
│   │   └── ConfigParser.swift               # Parses config.toml into CalendarConfig
│   └── CalendarCLI/
│       └── main.swift                        # CLI entry point (EventKit + AppKit)
└── Tests/
    └── CalendarLibTests/                     # Quick + Nimble test suite
        ├── ConfigParserSpec.swift
        └── RangeParserSpec.swift
```

Range parsing lives in GetClearKit (`RangeParser.swift`) and is shared across the suite.

## Tests

```bash
swift test
```
