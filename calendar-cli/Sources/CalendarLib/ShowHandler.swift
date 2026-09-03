// ShowHandler.swift

import Foundation
import GetClearKit

public func handleShow(
    args: [String], store: any CalendarStore, calFilter: String?, config: CalendarConfig
) async throws -> String {
    let parsed = try parseCommand(
        Array(args.dropFirst()), shape: CalendarCommandShapes.show, wrapError: CalendarHandlerError.init
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
        return formatAmbiguous(matches, title: title, command: "show")
    }

    var lines: [String] = [event.title]
    let cal = Calendar.current
    if event.isAllDay {
        lines.append("  Date:       \(eventDetailDateFormatter.string(from: event.startDate)) (all day)")
    } else {
        let end = event.endDate ?? event.startDate
        let sameDay = cal.isDate(event.startDate, inSameDayAs: end)
        let endPart = sameDay ? formatEventTime(end)
            : eventDetailDateFormatter.string(from: end) + " " + formatEventTime(end)
        lines
            .append(
                "  Date:       \(eventDetailDateFormatter.string(from: event.startDate)), \(formatEventTime(event.startDate)) – \(endPart)"
            )
    }
    lines.append("  Calendar:   \(event.calendarTitle)")
    if let loc = event.location, !loc.isEmpty { lines.append("  Location:   \(loc)") }
    if let url = event.url { lines.append("  URL:        \(url.absoluteString)") }
    if !event.attendees.isEmpty {
        let names = event.attendees.map { "\($0.name) (\($0.status))" }
        lines.append("  Attendees:  \(names.joined(separator: ", "))")
    }
    if let notes = event.notes, !notes.isEmpty {
        let noteLines = notes.components(separatedBy: "\n")
        lines.append("  Notes:      \(noteLines[0])")
        for line in noteLines.dropFirst() where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.append("              \(line)")
        }
    }
    return lines.joined(separator: "\n")
}
