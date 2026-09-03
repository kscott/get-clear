// RemoveHandler.swift

import Foundation
import GetClearKit

public func handleRemove(
    args: [String], store: any CalendarStore, calFilter: String?, config: CalendarConfig
) async throws -> String {
    let parsed = try parseCommand(
        Array(args.dropFirst()), shape: CalendarCommandShapes.remove, wrapError: CalendarHandlerError.init
    )
    let title = parsed.identifiers[0]
    let range = try resolvedRange(parsed.bareDateRange)
    let ids = try await resolvedIdentifiers(calFilter: calFilter, config: config, store: store)
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
