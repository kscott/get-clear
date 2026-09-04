func usage() -> String {
    """
    \(identity)
    
    Usage:
      mail setup [token]                   # Store JMAP token, discover identities
      mail send "<to>" [cc <cc>] [subject "<subject>"] [attach <file>] body "<text>"
      mail draft "<to>" [cc <cc>] [subject "<subject>"] [attach <file>] body "<text>"
      mail find "<query>"                  # Find messages for context before composing
      mail open                            # Open Fastmail in browser
    
    Argument shape — the same three sentences for every command in the suite:
      1. The name comes first, quoted if it contains a space.
      2. Mail has no date field.
      3. Everything else is "keyword value", in any order. body comes last,
         is required, and takes the rest of the line. cc and attach may each
         be given more than once — one email can go to several cc'd people
         or carry several attachments.
    
    Quoting: quote every value that contains a space — quoting one that
    doesn't is harmless, so when in doubt, quote. body is the one field
    where quotes are optional (it takes the rest of the line either way).
    
    Feedback: https://github.com/kscott/get-clear/issues
    """
}
