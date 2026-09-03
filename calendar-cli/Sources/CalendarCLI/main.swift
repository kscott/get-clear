// main.swift
// Entry point for the calendar-bin executable. Dispatch only — all logic lives in CalendarLib.

import AppKit
import CalendarEventKit
import CalendarLib
import GetClearKit

var args = Array(CommandLine.arguments.dropFirst())
let config = loadConfig()

var calFilter: String?
if let first = args.first,
   Command(rawValue: first.lowercased()) == nil,
   !isHelpFlag(first), !isVersionFlag(first),
   config.subsets[first.lowercased()] != nil
{
    calFilter = args.removeFirst()
}

await runCLI(args: args, identity: identity, usage: usage) { command, args in
    if command == .what {
        try print(handleWhat(args: args))
        return
    }

    do {
        if command == .open {
            _ = try handleOpen(args: args, opener: { NSWorkspace.shared.open($0) })
            return
        }

        let store = try await makeCalendarStore()

        switch command {
        case .calendars: try await print(handleCalendars(args: args, store: store))
        case .setup: try await print(handleSetup(args: args, store: store))
        case .list: try await print(handleList(args: args, store: store, calFilter: calFilter, config: config))
        case .today: try await print(handleToday(args: args, store: store, calFilter: calFilter, config: config))
        case .week: try await print(handleWeek(args: args, store: store, calFilter: calFilter, config: config))
        case .next: try await print(handleNext(args: args, store: store, calFilter: calFilter, config: config))
        case .find: try await print(handleFind(args: args, store: store, calFilter: calFilter, config: config))
        case .show: try await print(handleShow(args: args, store: store, calFilter: calFilter, config: config))
        case .add: try await print(handleAdd(args: args, store: store, calFilter: calFilter, config: config))
        case .remove: try await print(handleRemove(args: args, store: store, calFilter: calFilter, config: config))
        default: print(usage())
        }
    } catch let e as CalendarHandlerError {
        fail(e.description)
    } catch {
        fail(error.localizedDescription)
    }
}
