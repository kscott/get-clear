// Usage.swift
//
// Prints usage information and exits.

import Foundation
import GetClearKit

func usage() -> Never {
    print("""
    contacts \(versionString) — CLI for Apple Contacts

    Usage:
      contacts open                             # Open the Contacts app
      contacts lists                            # Show all contact groups
      contacts list <group>                     # Everyone in a group
      contacts export <group>                   # Paste-ready "Name <email>, ..." string
      contacts find <query>                     # Find by name, email, phone, company
      contacts show <name>                      # Full contact card
      contacts add <name> [email E] [phone P]
      contacts add <name> to <group>            # Add contact to a group
      contacts change <name> [add|remove] [email E] [phone P]
      contacts rename <name> <new-name>         # Rename a contact
      contacts remove <name>                    # Remove a contact
      contacts remove <name> from <group>       # Remove contact from a group

    Feedback: https://github.com/kscott/get-clear/issues
    """)
    exit(0)
}
