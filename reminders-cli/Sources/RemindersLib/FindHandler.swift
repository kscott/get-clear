// FindHandler.swift

import GetClearKit

public func handleFind(args: [String], store: any ReminderStore) async throws -> String {
    let parsed = try parseCommand(
        Array(args.dropFirst()), shape: ReminderCommandShapes.find, wrapError: ReminderHandlerError.init
    )
    let query = parsed.identifiers[0]
    let items = try await store.fetchIncomplete(in: nil)
    let matched = filtered(items, matching: query).sorted(by: comparator(for: .due))
    if matched.isEmpty {
        return "No reminders matching '\(query)'"
    }
    return matched
        .map { "\(calendarDot(hex: $0.list.color, ansiEnabled: ANSI.enabled))\(formatFindRow($0))" }
        .joined(separator: "\n")
}
