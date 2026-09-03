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
    let range = try resolvedRange(parsed.bareDateRange)
    let lower = query.lowercased()
    let ids = try await resolvedIdentifiers(calFilter: calFilter, config: config, store: store)
    let matches = try await store.fetchEvents(in: range.interval, calendarIdentifiers: ids)
        .filter { $0.title.lowercased().contains(lower) || ($0.notes?.lowercased().contains(lower) ?? false) }
    if matches.isEmpty { return "No events matching '\(query)' in \(formatRangeDescription(range))" }
    return formatGrouped(matches)
}
