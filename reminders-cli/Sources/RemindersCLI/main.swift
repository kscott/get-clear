// main.swift
// Entry point for reminders-bin. Dispatches to handlers in RemindersLib.

import AppKit
import GetClearKit
import RemindersLib

let args = Array(CommandLine.arguments.dropFirst())

await runCLI(args: args, identity: identity, usage: usage) { command, args in
    do {
        if command == .open {
            try handleOpen(args: args, opener: { NSWorkspace.shared.open($0) })
            return
        }

        let store = await makeReminderStore()

        switch command {
        case .what: try await print(handleWhat(args: args))
        case .lists: try await print(handleLists(args: args, store: store))
        case .list: try await print(handleList(args: args, store: store))
        case .find: try await print(handleFind(args: args, store: store))
        case .show: try await print(handleShow(args: args, store: store))
        case .add: try await print(handleAdd(args: args, store: store))
        case .change: try await print(handleChange(args: args, store: store))
        case .done: try await print(handleDone(args: args, store: store))
        case .rename: try await print(handleRename(args: args, store: store))
        case .remove: try await print(handleRemove(args: args, store: store))
        default: print(usage())
        }
    } catch let e as ReminderHandlerError {
        fail(e.message)
    } catch {
        fail(error.localizedDescription)
    }
}
