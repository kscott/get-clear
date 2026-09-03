// CalendarsHandler.swift

import Foundation
import GetClearKit

public func handleCalendars(args: [String], store: any CalendarStore) async throws -> String {
    _ = try parseCommand(
        Array(args.dropFirst()), shape: CalendarCommandShapes.calendars, wrapError: CalendarHandlerError.init
    )
    let all = try await store.fetchCalendars()
    let grouped = Dictionary(grouping: all) { $0.source ?? "" }
    return grouped.keys.sorted().map { source in
        let header = source.isEmpty ? "" : source + "\n"
        let cals = (grouped[source] ?? []).sorted { $0.title < $1.title }
        let lines = cals.map { "  \(calendarDot(hex: $0.color))\($0.title)" }
        return header + lines.joined(separator: "\n")
    }.joined(separator: "\n")
}
