// main.swift
//
// Entry point for contacts-bin: argument parsing and command dispatch only.

import Foundation
import Contacts
import ContactsLib
import GetClearKit

let store     = CNContactStore()
let semaphore = DispatchSemaphore(value: 0)
let args      = Array(CommandLine.arguments.dropFirst())

runCLI(args: args, identity: identity, usage: usage) { command, args in
    store.requestAccess(for: .contacts) { granted, _ in
        guard granted else { fail("Contacts access denied") }

        switch command {
        case .open:   handleOpen(semaphore: semaphore)
        case .what:   handleWhat(args: args, semaphore: semaphore)
        case .lists:  handleLists(store: store, semaphore: semaphore)
        case .list:   handleList(args: args, store: store, semaphore: semaphore)
        case .export: handleExport(args: args, store: store, semaphore: semaphore)
        case .find:   handleFind(args: args, store: store, semaphore: semaphore)
        case .show:   handleShow(args: args, store: store, semaphore: semaphore)
        case .add:    handleAdd(args: args, store: store, semaphore: semaphore)
        case .change: handleChange(args: args, store: store, semaphore: semaphore)
        case .rename: handleRename(args: args, store: store, semaphore: semaphore)
        case .remove: handleRemove(args: args, store: store, semaphore: semaphore)
        default:      usage()
        }
    }
}

semaphore.wait()
UpdateChecker.spawnBackgroundCheckIfNeeded()
