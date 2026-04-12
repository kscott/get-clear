// DefaultCommand.swift
//
// Handles bare range shorthands: "calendar monday", "calendar 7d", "calendar march 15", etc.
// Tries the full argument string as a range before falling through to usage().

import EventKit
import CalendarLib
import GetClearKit

func handleDefault(args: [String], store: EKEventStore, calFilter: String?,
                   config: CalendarConfig, semaphore: DispatchSemaphore) {
    let rangeStr = args.joined(separator: " ")
    guard let range = parseRange(rangeStr) else { usage() }
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
}
