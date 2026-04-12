// main.swift
//
// Entry point for the calendar-bin executable.
// Argument parsing and dispatch only — all logic lives in CalendarLib or CalendarCLI helpers.

import Foundation
import AppKit
import EventKit
import CalendarLib
import GetClearKit

let versionString = "\(builtVersion) (Get Clear \(suiteVersion))"

let store     = EKEventStore()
let semaphore = DispatchSemaphore(value: 0)
var args      = Array(CommandLine.arguments.dropFirst())

let config = loadConfig()

let knownCommands: Set<String> = [
    "open", "calendars", "setup", "list", "today", "week", "next",
    "find", "show", "add", "remove"
]

var calFilter: String? = nil
if let first = args.first,
   !knownCommands.contains(first.lowercased()),
   !isHelpFlag(first), !isVersionFlag(first),
   config.subsets[first.lowercased()] != nil {
    calFilter = args.removeFirst()
}

let dispatch = parseArgs(args)
if case .version = dispatch { print(versionString); exit(0) }
guard case .command(let cmd, let args) = dispatch else { usage() }

store.requestFullAccessToEvents { granted, _ in
    guard granted else { fail("Calendar access denied") }

    switch cmd {
    case "what":      handleWhat(args: args, semaphore: semaphore)
    case "open":      NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app")); semaphore.signal()
    case "calendars": handleCalendars(store: store, semaphore: semaphore)
    case "setup":     runSetup(store: store); semaphore.signal()
    case "list":      handleList(args: args, store: store, calFilter: calFilter, config: config, semaphore: semaphore)
    case "today":     handleToday(store: store, calFilter: calFilter, config: config, semaphore: semaphore)
    case "week":      handleWeek(store: store, calFilter: calFilter, config: config, semaphore: semaphore)
    case "next":      handleNext(args: args, store: store, calFilter: calFilter, config: config, semaphore: semaphore)
    case "find":      handleFind(args: args, store: store, calFilter: calFilter, config: config, semaphore: semaphore)
    case "show":      handleShow(args: args, store: store, semaphore: semaphore)
    case "add":       handleAdd(args: args, store: store, calFilter: calFilter, config: config, semaphore: semaphore)
    case "remove":    handleRemove(args: args, store: store, calFilter: calFilter, config: config, semaphore: semaphore)
    default:
        let rangeStr = args.joined(separator: " ")
        if let range = parseRange(rangeStr) {
            let evts = fetchEvents(in: range, calendars: resolveCalendars(calFilter, store: store, config: config), store: store).map(displayData)
            if evts.isEmpty { print("No events — \(formatRangeDescription(range))") }
            else if range.isSingleDay { printFlat(evts, showHeader: true, header: dayHeaderFormatter.string(from: range.start), calFilter: calFilter) }
            else { printGrouped(evts, calFilter: calFilter) }
        } else { usage() }
        semaphore.signal()
    }
}

semaphore.wait()
UpdateChecker.spawnBackgroundCheckIfNeeded()
if let hint = UpdateChecker.hint() { fputs(hint + "\n", stderr) }
