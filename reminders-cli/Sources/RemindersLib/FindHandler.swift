// FindHandler.swift

import GetClearKit

public func handleFind(args: [String], store: any ReminderStore) async throws -> String {
    let parsed: ParsedCommand
    do {
        parsed = try parseCommand(Array(args.dropFirst()), shape: ReminderCommandShapes.find)
    } catch let e as ArgumentError {
        throw ReminderHandlerError(e.errorDescription ?? "invalid arguments")
    }
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
