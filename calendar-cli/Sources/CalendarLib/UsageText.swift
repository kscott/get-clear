// UsageText.swift

import Foundation

public func usageText() -> String {
    """
    calendar — manage Calendar events
    
    Usage:
      calendar [subset] <command> [args]
    
    Commands:
      today                            Events today
      week                             Events this week
      next [<count>]                   Next N upcoming events (default 5)
      list <range>                     Events in a date range (e.g. list monday, list 7d)
      find "<query>" [<range>]         Find events matching a query
      show "<title>" [<range>]         Show event details
      add "<title>" ["<date/time>"]    Add an event
      remove "<title>" [<range>]       Remove an event
      calendars                        List available calendars
      setup                            Configure calendar subsets
      what [range]                     Recent calendar activity
      open                             Open the Calendar app
    
    Argument shape — the name comes first, quoted if it contains a space. The
    date, time, or range comes right after — bare, no keyword needed.
    
    Quote every value that contains a space; quoting one that doesn't is harmless.
    
    Ranges: today, tomorrow, week, 7d, 30d, "march 15 to march 20", monday, etc.
    """
}
