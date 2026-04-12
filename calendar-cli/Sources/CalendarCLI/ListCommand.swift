// ListCommand.swift

import EventKit
import CalendarLib
import GetClearKit

func handleList(args: [String], store: EKEventStore, calFilter: String?,
                config: CalendarConfig, semaphore: DispatchSemaphore) {
    guard args.count > 1 else { fail("provide a range (e.g. today, week, 7d, \"march 15 to march 20\")") }
    let rangeStr = args.dropFirst().joined(separator: " ")
    guard let range = parseRange(rangeStr) else { fail("unrecognised range: \(rangeStr)") }
    let evts = fetchEvents(in: range, calendars: resolveCalendars(calFilter, store: store, config: config),
                           store: store).map(displayData)
    if evts.isEmpty {
        print("No events — \(formatRangeDescription(range))")
    } else if range.isSingleDay {
        printFlat(evts, showHeader: true, header: dayHeaderFormatter.string(from: range.start))
    } else {
        printGrouped(evts)
    }
    semaphore.signal()
}
