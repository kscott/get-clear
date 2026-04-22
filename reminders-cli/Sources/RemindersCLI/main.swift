// main.swift
//
// Entry point for reminders-bin. Argument dispatch and EventKit lifecycle only.
// Business logic lives in RemindersLib. EventKit helpers live in RemindersCLI/*.swift.

import Foundation
import EventKit
import RemindersLib
import GetClearKit

let store = EKEventStore()
let semaphore = DispatchSemaphore(value: 0)
let args = Array(CommandLine.arguments.dropFirst())

runCLI(args: args, identity: identity, usage: usage) { command, args in
    store.requestFullAccessToReminders { granted, _ in
        guard granted else { fail("Reminders access denied") }

        switch command {
        case .what:   handleWhat(args: args, semaphore: semaphore)
        case .open:   handleOpen(semaphore: semaphore)
        case .lists:  handleLists(store: store, semaphore: semaphore)
        case .list:   handleList(args: args, store: store, semaphore: semaphore)
        case .add:    handleAdd(args: args, store: store, semaphore: semaphore)
        case .change: handleChange(args: args, store: store, semaphore: semaphore)
        case .show:   handleShow(args: args, store: store, semaphore: semaphore)
        case .rename: handleRename(args: args, store: store, semaphore: semaphore)
        case .find:   handleFind(args: args, store: store, semaphore: semaphore)
        case .done:   handleDone(args: args, store: store, semaphore: semaphore)
        case .remove: handleRemove(args: args, store: store, semaphore: semaphore)
        default:      usage()
        }
    }
}

semaphore.wait()

UpdateChecker.spawnBackgroundCheckIfNeeded()
if let hint = UpdateChecker.hint() { fputs(hint + "\n", stderr) }
