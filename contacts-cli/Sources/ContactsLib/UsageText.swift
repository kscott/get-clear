public func usageText(identity: String) -> String {
    """
    \(identity)

    Usage:
      contacts open                              # Open the Contacts app
      contacts lists                             # Show all contact groups
      contacts list <group>                      # Everyone in a group
      contacts export <group>                    # Paste-ready "Name <email>, ..." string
      contacts find <query>                      # Find by name, email, phone, company
      contacts show <name>                       # Full contact card
      contacts add <name> [email E] [phone P] [company C]
      contacts add <name> to <group>             # Add contact to a group
      contacts change <name> [add|remove] [email E] [phone P] [company C]
      contacts rename <name> <new-name>          # Rename a contact
      contacts remove <name>                     # Remove a contact
      contacts remove <name> from <group>        # Remove contact from a group

    Feedback: https://github.com/kscott/get-clear/issues
    """
}
