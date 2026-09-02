// ListHandler.swift

import GetClearKit

public func handleList(args: [String], store: any ReminderStore) async throws -> String {
    let parsed = try parseCommand(
        Array(args.dropFirst()), shape: ReminderCommandShapes.list, wrapError: ReminderHandlerError.init
    )
    let filterName = parsed.identifiers.first

    var order: ReminderSortOrder = .due
    if let by = parsed.values["by"] {
        guard let parsedOrder = ReminderSortOrder(rawValue: by.lowercased()) else {
            throw ReminderHandlerError("unknown sort: \(by)")
        }
        order = parsedOrder
    }

    let allLists = try await store.fetchLists()
    let targetList = try resolvedList(named: filterName, from: allLists)

    let items = try await store.fetchIncomplete(in: targetList)

    if targetList != nil {
        return sorted(items, by: order)
            .map { "\(calendarDot(hex: $0.list.color, ansiEnabled: ANSI.enabled))\(formatListRow($0))" }
            .joined(separator: "\n")
    } else {
        var lines: [String] = []
        for (list, groupItems) in groupedByList(items, sortedBy: order) {
            let dot = calendarDot(hex: list.color, ansiEnabled: ANSI.enabled)
            lines.append("\(dot)\(ANSI.bold(list.title))")
            lines.append(contentsOf: groupItems.map { "\(dot)\(formatListRow($0))" })
        }
        return lines.joined(separator: "\n")
    }
}
