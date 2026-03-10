# calendar-cli

A command-line tool that lets Claude read and query your Apple Calendar — just by asking.

Instead of switching to Calendar.app, you ask Claude what's coming up and it handles it. The tool connects directly to Apple's native Calendar framework, so all your existing calendars — including external ones like Google or Exchange configured in Calendar.app — work exactly as before.

## Using with Claude

This is the main use case. Tell Claude what you want in plain language:

> "What's on my calendar this week?"
> "Do I have anything tomorrow afternoon?"
> "What does my week look like — just work stuff?"
> "Show me everything I have in March"
> "What's coming up next?"
> "Add a team standup tomorrow at 9am"
> "Remove the budget review on Friday"

Claude translates your words into the right commands, filters to the right calendars, and formats the results clearly.

### Tips for best results

- **Use named subsets** — once you set up a config file, "just work stuff" or "personal only" works naturally
- **Be specific about range** — "this week", "next two weeks", "march 15 to march 20" all work
- **Ask what's next** — "what are my next 5 events" gives a quick at-a-glance view

## Setup

### Requirements

- **macOS 14 (Sonoma) or later**
- **Apple Silicon Mac** (arm64) for the pre-built binary; Intel Macs must build from source
- **`~/bin` in your `$PATH`** — the installer puts the binary there. If `calendar` isn't found after install, add this to your `~/.zshrc`:

  ```bash
  export PATH="$HOME/bin:$PATH"
  ```

### Install (pre-built binary — no Xcode required)

1. Download `calendar-bin` from the [latest release](https://github.com/kscott/calendar-cli/releases/latest)
2. Move it into `~/bin/` and make it executable:

```bash
mkdir -p ~/bin
mv ~/Downloads/calendar-bin ~/bin/calendar-bin
chmod +x ~/bin/calendar-bin
```

On first run, macOS will prompt you to grant Calendar access.

### Build from source (requires Xcode Command Line Tools)

```bash
xcode-select --install   # if not already installed
git clone https://github.com/kscott/calendar-cli.git ~/dev/calendar-cli
~/dev/calendar-cli/calendar setup
```

## Command reference

```
calendar                                      # Show help
calendar --version                            # Show version
calendar open                                 # Open Calendar.app
calendar calendars                            # List all available calendars
calendar list <range>                         # Events in range
calendar today                                # Today's events
calendar week                                 # This week's events
calendar next [n]                             # Next N events (default 5)
calendar find <query> [range]
calendar show <title> [date]                  # Full event detail
calendar add <title> [date] [time to time]
calendar remove <title> [date]
```

Prefix a subset name to filter by calendar group:

```bash
calendar work today
calendar personal week
calendar work next 5
calendar work find standup
```

Bare range shorthands also work without the `list` subcommand:

```bash
calendar monday
calendar 7d
calendar "march 15"
calendar "next monday to friday"
```

### Range formats

| Format | Example |
|--------|---------|
| Relative days | `today`, `tomorrow`, `yesterday` |
| Week spans | `week`, `this week`, `next week`, `last week` |
| Month spans | `month`, `next month`, `last month` |
| Weekday | `monday` … `sunday` (next occurrence, or today if today) |
| Month + day | `march 15` (rolls to next year if past) |
| ISO date | `2026-03-15` |
| Short numeric | `3/15` (rolls to next year if past) |
| N-day window | `7d`, `30d` (today through today+N-1) |
| Explicit range | `march 15 to march 20` |
| Relative range | `next monday to friday` |

### Config file

Create `~/.config/calendar-cli/config.toml` to define named subsets:

```toml
[subsets]
work     = ["Work", "Meetings", "Google Calendar"]
personal = ["Home", "Family", "Doctor Appointments"]
sports   = ["Colorado Avalanche", "Denver Nuggets", "Colorado Rockies"]
church   = ["Trinity UMC"]
```

Subset names are case-insensitive. Calendar names must match exactly as shown in `calendar calendars`.

### Output format

**Single day** — flat list with day header:
```
Monday, March 9
   9:00 AM – 10:00 AM   Standup · Zoom
  10:30 AM – 11:30 AM   1:1 with Sarah
   2:00 PM –  3:00 PM   Budget Review
   All day               Board Retreat
```

**Multi-day** — grouped by day, empty days omitted:
```
Monday, March 9
   9:00 AM – 10:00 AM   Standup

Tuesday, March 10
   All day               Spring Break
   2:00 PM –  3:00 PM   Dentist · 123 Main St
```

**`next N`** — compact with relative date:
```
  Today      9:00 AM   Standup · Zoom
  Tomorrow  10:00 AM   Dentist
  Wed 3/11   3:00 PM   Team sync
```

## Known limitations

- `add` creates events in the first calendar of the subset filter, or your default calendar
- `show` and `remove` with multiple matches list candidates and ask you to narrow by date
- Attendee details only available for events with invitations
- External calendars must be configured in Calendar.app to be visible

## Project structure

```
calendar-cli/
├── Package.swift                         # Swift Package Manager manifest
├── calendar                              # Wrapper script (symlinked into ~/bin)
├── Sources/
│   ├── CalendarLib/
│   │   ├── TimeRangeParser.swift         # Range parsing logic (no Apple framework deps)
│   │   └── ConfigParser.swift            # TOML config parsing (no Apple framework deps)
│   └── CalendarCLI/
│       └── main.swift                    # CLI entry point (EventKit + AppKit)
└── Tests/
    └── CalendarLibTests/
        └── main.swift                    # Test runner (no Xcode required)
```

## Tests

```bash
calendar test
```

Builds and runs the test suite against the range and config parsing logic. No Xcode required.
