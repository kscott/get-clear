// UsageText.swift

public func usageText() -> String {
    """
    Usage:
      reminders open                                   # Open the Reminders app
      reminders lists                                  # Show all reminder lists
      reminders list ["<name>"] [by due|priority|title|created]
      reminders add "<name>" ["<date>"] [list "<name>"] [priority high|medium|low|none]
                    [repeat <freq>] [url <url>] [note "<text>"]
      reminders change "<name>" ["<date>"] [list "<name>"] [priority ...]
                    [repeat <freq>] [url <url>] [note "<text>"]
      reminders rename "<name>" "<new name>" [list "<name>"]
      reminders find "<query>"                         # Search titles and notes
      reminders show "<name>" [list "<name>"]
      reminders done "<name>" [list "<name>"]
      reminders remove "<name>" [list "<name>"]
    
    Argument shape — the same three sentences for every command in the suite:
      1. The name comes first, quoted if it contains a space. A bare word that is
         also a keyword (list, due, …) needs quotes to be used as the name:
         reminders add "list".
      2. A due date is either bare right after the name or introduced by "due"
         (or "date") anywhere — one or the other, never both. An optional "on"
         reads naturally in either form (due on friday, on march 1).
      3. Everything else is "keyword value", in any order. note comes last and
         takes the rest of the line.
    
    Quoting: quote every value that contains a space — quoting one that doesn't
    is harmless, so when in doubt, quote.
    
    Date examples:
      tomorrow, friday, "next friday", "march 15", "2026-03-10", 3pm, "friday at 5pm"
    
    Keywords (any order, note must be last):
      list "<name>"
      due "<date>" / date "<date>"                     (or a bare date right after the name)
      repeat daily / repeat weekly / repeat "every 2 weeks"
      priority high / priority medium / priority low / priority none
      url https://example.com
      note "your free text goes here to end of line"
    
    Clear a field with change:
      due none / repeat none / note none / url none / priority none
    
    Feedback: https://github.com/kscott/get-clear/issues
    """
}
