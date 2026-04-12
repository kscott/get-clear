// DefaultCommand.swift
//
// Handles bare range shorthands: "calendar monday", "calendar 7d", "calendar march 15", etc.
// Returns true if the args parsed as a range and were handled; false if not.

import EventKit
import CalendarLib
import GetClearKit

@discardableResult
func handleDefault(args: [String], store: EKEventStore, calFilter: String?,
                   config: CalendarConfig, semaphore: DispatchSemaphore) -> Bool {
    let rangeStr = args.joined(separator: " ")
    guard let range = parseRange(rangeStr) else { return false }
    let evts = fetchEvents(in: range, calendars: resolveCalendars(calFilter, store: store, config: config),
                           store: store).map(displayData)
    if evts.isEmpty {
        print("No events — \(formatRangeDescription(range))")
    } else if range.isSingleDay {
        printFlat(evts, showHeader: true, header: dayHeaderFormatter.string(from: range.start),
                  calFilter: calFilter)
    } else {
        printGrouped(evts, calFilter: calFilter)
    }
    semaphore.signal()
    return true
}
