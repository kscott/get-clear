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
        switch command {
        case .what:   print(try await handleWhat(args: args))
        case .lists:  print(try await handleLists(store: store))
        case .list:   print(try await handleList(args: args, store: store))
        case .find:   print(try await handleFind(args: args, store: store))
        case .show:   print(try await handleShow(args: args, store: store))
        case .add:    print(try await handleAdd(args: args, store: store))
        case .change: print(try await handleChange(args: args, store: store))
        case .done:   print(try await handleDone(args: args, store: store))
        case .rename: print(try await handleRename(args: args, store: store))
        case .remove: print(try await handleRemove(args: args, store: store))
        default:      print(usage())
        }
    } catch let e as ReminderHandlerError {
        fail(e.message)
    } catch {
        fail(error.localizedDescription)
    }
}
