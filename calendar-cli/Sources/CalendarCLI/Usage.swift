// Usage.swift

import Foundation
import GetClearKit

func usage() -> Never {
    print("""
    calendar \(versionString) — CLI for Apple Calendar

    Usage:
      calendar open                               # Open the Calendar app
      calendar calendars                          # List all available calendars
      calendar setup                              # Set up calendar groups
      calendar list <range>                       # Events in range
      calendar today                              # Today's events
      calendar week                               # This week's events
      calendar next [n]                           # Next N events (default 5)
      calendar find <query> [range]
      calendar show <title> [date]                # Full event detail
      calendar add <title> [date] [time to time]
      calendar remove <title> [date]

    Prefix a subset name to filter by calendar group:
      calendar work today
      calendar personal week

    Range: today, tomorrow, week, month, monday, "march 15", "march 15 to march 20", 7d
    Config: ~/.config/calendar-cli/config.toml
    Feedback: https://github.com/kscott/get-clear/issues
    """)
    exit(0)
}
