// FindHandler.swift

import Foundation
import GetClearKit

public func handleFind(
    args: [String], store: any CalendarStore, calFilter: String?, config: CalendarConfig
) async throws -> String {
    let parsed = try parseCommand(
        Array(args.dropFirst()), shape: CalendarCommandShapes.find, wrapError: CalendarHandlerError.init
    )
    let query = parsed.identifiers[0]
    let range: ParsedRange
    if let rangeStr = parsed.bareDateRange {
        guard let r = parseRange(rangeStr) else {
            throw CalendarHandlerError("unrecognised range: \(rangeStr)")
        }
        range = r
    } else {
        range = parseRange("30d")!
    }
    let lower = query.lowercased()
    let ids = try await resolvedIdentifiers(calFilter: calFilter, config: config, store: store)
    if ids?.isEmpty == true { fail("No calendars matched filter '\(calFilter!)'") }
    let matches = try await store.fetchEvents(in: range.interval, calendarIdentifiers: ids)
        .filter { $0.title.lowercased().contains(lower) || ($0.notes?.lowercased().contains(lower) ?? false) }
    if matches.isEmpty { return "No events matching '\(query)' in \(formatRangeDescription(range))" }
    return formatGrouped(matches)
}
