// main.swift
// Entry point for the calendar-bin executable. Dispatch only — all logic lives in CalendarLib.

import AppKit
import CalendarLib
import CalendarEventKit
import GetClearKit

var args = Array(CommandLine.arguments.dropFirst())
let config = loadConfig()

var calFilter: String? = nil
if let first = args.first,
   Command(rawValue: first.lowercased()) == nil,
   !isHelpFlag(first), !isVersionFlag(first),
   config.subsets[first.lowercased()] != nil {
    calFilter = args.removeFirst()
}

await runCLI(args: args, identity: identity, usage: usage) { command, args in
    if command == .open {
        _ = handleOpen(opener: { NSWorkspace.shared.open($0) })
        return
    }
    if command == .what {
        print(try handleWhat(args: args))
        return
    }

    let store = try await makeCalendarStore()

    do {
        switch command {
        case .calendars: print(try await handleCalendars(store: store))
        case .setup:     print(try await handleSetup(store: store))
        case .list:      print(try await handleList(args: args, store: store, calFilter: calFilter, config: config))
        case .today:     print(try await handleToday(store: store, calFilter: calFilter, config: config))
        case .week:      print(try await handleWeek(store: store, calFilter: calFilter, config: config))
        case .next:      print(try await handleNext(args: args, store: store, calFilter: calFilter, config: config))
        case .find:      print(try await handleFind(args: args, store: store, calFilter: calFilter, config: config))
        case .show:      print(try await handleShow(args: args, store: store, calFilter: calFilter, config: config))
        case .add:       print(try await handleAdd(args: args, store: store, calFilter: calFilter, config: config))
        case .remove:    print(try await handleRemove(args: args, store: store, calFilter: calFilter, config: config))
        default:         print(usage())
        }
    } catch let e as CalendarHandlerError {
        fail(e.description)
    } catch {
        fail(error.localizedDescription)
    }
}
