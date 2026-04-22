// main.swift
//
// Entry point for reminders-bin. Argument dispatch and EventKit lifecycle only.
// Business logic lives in RemindersLib. EventKit helpers live in RemindersCLI/*.swift.

import Foundation
import EventKit
import GetClearKit

let store = EKEventStore()
let args  = Array(CommandLine.arguments.dropFirst())

await runCLI(args: args, identity: identity, usage: usage) { command, args in
    let granted = try await store.requestFullAccessToReminders()
    guard granted else { fail("Reminders access denied") }

    switch command {
    case .what:   await handleWhat(args: args)
    case .open:   await handleOpen()
    case .lists:  await handleLists(store: store)
    case .list:   await handleList(args: args, store: store)
    case .add:    await handleAdd(args: args, store: store)
    case .change: await handleChange(args: args, store: store)
    case .show:   await handleShow(args: args, store: store)
    case .rename: await handleRename(args: args, store: store)
    case .find:   await handleFind(args: args, store: store)
    case .done:   await handleDone(args: args, store: store)
    case .remove: await handleRemove(args: args, store: store)
    default:      usage()
    }
}
