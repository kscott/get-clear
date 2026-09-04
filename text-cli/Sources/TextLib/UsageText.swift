// UsageText.swift
// Usage string for the text tool — commands and feedback link.

public func usageText() -> String {
    """
    Usage:
      text send "<contact>" message "<text>"     # Send a message
      text open                                  # Open Messages.app
    
    Argument shape — the same three sentences for every command in the suite:
      1. The name comes first, quoted if it contains a space.
      2. Text has no date field.
      3. Everything else is "keyword value", in any order. message comes
         last and takes the rest of the line.
    
    Quoting: quote every value that contains a space — quoting one that
    doesn't is harmless, so when in doubt, quote. message is the one
    field where quotes are optional (it takes the rest of the line either
    way): "text send Marcus message running late" and
    "text send Marcus message \"running late\"" are the same.
    
    Feedback: https://github.com/kscott/get-clear/issues
    """
}
