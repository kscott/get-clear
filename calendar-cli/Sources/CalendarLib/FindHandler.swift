// FindHandler.swift

import Foundation
import GetClearKit

public func handleFind(
    args: [String], store: any CalendarStore, calFilter: String?, config: CalendarConfig
) async throws -> String {
    guard args.count > 1 else { throw CalendarHandlerError("provide a search query") }
    let rem = Array(args.dropFirst())
    let query: String
    let range: ParsedRange
    if rem.count > 1, let r = parseRange(rem.dropFirst().joined(separator: " ")) {
        query = rem[0]; range = r
    } else if rem.count > 1, let r = parseRange(rem.last!) {
        query = rem.dropLast().joined(separator: " "); range = r
    } else {
        query = rem.joined(separator: " "); range = parseRange("30d")!
    }
    let lower = query.lowercased()
    let ids   = try await resolvedIdentifiers(calFilter: calFilter, config: config, store: store)
    if ids?.isEmpty == true { fail("No calendars matched filter '\(calFilter!)'") }
    let matches = try await store.fetchEvents(in: range.interval, calendarIdentifiers: ids)
        .filter { $0.title.lowercased().contains(lower) || ($0.notes?.lowercased().contains(lower) ?? false) }
    if matches.isEmpty { return "No events matching '\(query)' in \(formatRangeDescription(range))" }
    return formatGrouped(matches)
}
