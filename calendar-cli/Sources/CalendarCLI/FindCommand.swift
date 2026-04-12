// FindCommand.swift

import EventKit
import CalendarLib
import GetClearKit

func handleFind(args: [String], store: EKEventStore, calFilter: String?,
                config: CalendarConfig, semaphore: DispatchSemaphore) {
    guard args.count > 1 else { fail("provide a search query") }
    let rem = Array(args.dropFirst())
    var query: String; var range: ParsedRange
    if rem.count > 1, let r = parseRange(rem.dropFirst().joined(separator: " ")) {
        query = rem[0]; range = r
    } else if rem.count > 1, let r = parseRange(rem.last!) {
        query = rem.dropLast().joined(separator: " "); range = r
    } else {
        query = rem.joined(separator: " "); range = parseRange("30d")!
    }
    let lower   = query.lowercased()
    let matches = fetchEvents(in: range,
                              calendars: resolveCalendars(calFilter, store: store, config: config),
                              store: store)
        .filter { ($0.title?.lowercased().contains(lower) ?? false) ||
                  ($0.notes?.lowercased().contains(lower) ?? false) }
        .map(displayData)
    if matches.isEmpty {
        print("No events matching '\(query)' in \(formatRangeDescription(range))")
    } else {
        printGrouped(matches)
    }
    semaphore.signal()
}
