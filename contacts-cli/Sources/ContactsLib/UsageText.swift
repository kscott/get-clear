public func usageText(identity: String) -> String {
    """
    \(identity)
    
    Usage:
      contacts open                              # Open the Contacts app
      contacts lists                             # Show all contact groups
      contacts list "<group>"                    # Everyone in a group
      contacts find "<query>"                    # Find by name, email, phone, company
      contacts show "<name>"                     # Full contact card
      contacts add "<name>" [email <e>] [phone <p>] [company "<c>"]
      contacts add "<name>" to "<group>"         # Add an existing contact to a group
      contacts change "<name>" [add|remove] [email <e>] [phone <p>] [company "<c>"]
      contacts rename "<name>" "<new name>"      # Rename a contact
      contacts remove "<name>"                   # Remove a contact
      contacts remove "<name>" from "<group>"    # Remove contact from a group
    
    Argument shape — the same three sentences for every command in the suite:
      1. The name comes first, quoted if it contains a space. A bare word that is
         also a keyword (email, to, …) needs quotes to be used as the name.
      2. Contacts has no date field.
      3. Everything else is "keyword value", in any order.
    
    Quoting: quote every value that contains a space — quoting one that doesn't
    is harmless, so when in doubt, quote.
    
    change's email/phone accept a wider syntax (a contact can hold several):
      email "<value>"                 add a value
      email "<old>" "<new>"           replace one value with another
      add email "<value>" / remove email "<value>"
      email none                      clear
      (phone works the same way; company takes one value, no add/remove)
    
    Feedback: https://github.com/kscott/get-clear/issues
    """
}
