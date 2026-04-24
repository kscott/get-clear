// main.swift
// Entry point for reminders-bin. Requests EventKit access, creates AppleReminderStore,
// dispatches to handlers in RemindersLib.

import EventKit
import GetClearKit
import RemindersLib
import RemindersEventKit

let ek   = EKEventStore()
let args = Array(CommandLine.arguments.dropFirst())

await runCLI(args: args, identity: identity, usage: usage) { command, args in
    if command == .open { await handleOpen(); return }

    let granted = try await ek.requestFullAccessToReminders()
    guard granted else { fail("Reminders access denied") }
    let store = AppleReminderStore(ek)

    do {
        let output: String
        switch command {
        case .what:   output = try await handleWhat(args: args)
        case .lists:  output = try await handleLists(store: store)
        case .list:   output = try await handleList(args: args, store: store)
        case .find:   output = try await handleFind(args: args, store: store)
        case .show:   output = try await handleShow(args: args, store: store)
        case .add:    output = try await handleAdd(args: args, store: store)
        case .change: output = try await handleChange(args: args, store: store)
        case .done:   output = try await handleDone(args: args, store: store)
        case .rename: output = try await handleRename(args: args, store: store)
        case .remove: output = try await handleRemove(args: args, store: store)
        default:      usage()
        }
        print(output)
    } catch let e as ReminderHandlerError {
        fail(e.message)
    } catch {
        fail(error.localizedDescription)
    }
}
