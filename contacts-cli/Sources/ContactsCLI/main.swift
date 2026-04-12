// main.swift
//
// Entry point for contacts-bin: argument parsing and command dispatch only.

import Foundation
import AppKit
import Contacts
import ContactsLib
import GetClearKit

let versionString = "\(builtVersion) (Get Clear \(suiteVersion))"

let store     = CNContactStore()
let semaphore = DispatchSemaphore(value: 0)
let args      = Array(CommandLine.arguments.dropFirst())

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

runCLI(args: args, version: versionString, usage: usage) { command, args in
    store.requestAccess(for: .contacts) { granted, _ in
        guard granted else { fail("Contacts access denied") }

        switch command {
        case .open:
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Contacts.app"))
            semaphore.signal()
        case .what:
            handleWhat(args: args, semaphore: semaphore)
        case .lists:
            let groups = (try? store.groups(matching: nil)) ?? []
            for g in groups.sorted(by: { $0.name < $1.name }) { print(g.name) }
            semaphore.signal()
        case .list:
            handleList(args: args, store: store, semaphore: semaphore)
        case .export:
            handleExport(args: args, store: store, semaphore: semaphore)
        case .find:
            handleFind(args: args, store: store, semaphore: semaphore)
        case .show:
            handleShow(args: args, store: store, semaphore: semaphore)
        case .add:
            handleAdd(args: args, store: store, semaphore: semaphore)
        case .change:
            handleChange(args: args, store: store, semaphore: semaphore)
        case .rename:
            handleRename(args: args, store: store, semaphore: semaphore)
        case .remove:
            handleRemove(args: args, store: store, semaphore: semaphore)
        default:
            usage()
        }
    }
}

semaphore.wait()
UpdateChecker.spawnBackgroundCheckIfNeeded()
