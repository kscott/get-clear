// RemoveHandler.swift

import Foundation
import GetClearKit

public func handleRemove(
    args: [String], store: any CalendarStore, calFilter: String?, config: CalendarConfig
) async throws -> String {
    guard args.count > 1 else { throw CalendarHandlerError("provide an event title") }
    let title = args[1]
    let rangeStr = args.count > 2 ? args.dropFirst(2).joined(separator: " ") : nil
    let range = rangeStr.flatMap { parseRange($0) } ?? parseRange("30d")!
    let ids = try await resolvedIdentifiers(calFilter: calFilter, config: config, store: store)
    if ids?.isEmpty == true { fail("No calendars matched filter '\(calFilter!)'") }
    let event: EventItem
    do {
        event = try await store.resolve(title: title, in: range.interval, calendarIdentifiers: ids)
    } catch let CalendarStoreError.notFound(t) {
        throw CalendarHandlerError("Not found: \(t)")
    } catch let CalendarStoreError.ambiguous(matches) {
        return formatAmbiguous(matches, title: title, command: "remove")
    }
    try await store.remove(identifier: event.identifier)
    try? ActivityLog.write(tool: "calendar", cmd: "remove", desc: event.title, container: event.calendarTitle)
    return "Removed: \(event.title) (\(shortDateFormatter.string(from: event.startDate)))"
}
