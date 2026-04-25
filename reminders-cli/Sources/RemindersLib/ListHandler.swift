// ListHandler.swift

import GetClearKit

public func handleList(args: [String], store: any ReminderStore) async throws -> String {
    var listArgs = Array(args.dropFirst())
    var order: ReminderSortOrder = .due
    if let byIdx = listArgs.firstIndex(of: "by"), byIdx + 1 < listArgs.count {
        order = ReminderSortOrder(rawValue: listArgs[byIdx + 1].lowercased()) ?? .due
        listArgs.removeSubrange(byIdx...(byIdx + 1))
    }
    let filterName = listArgs.first

    let allLists  = try await store.fetchLists()
    let targetList = try resolvedList(named: filterName, from: allLists)

    let items = try await store.fetchIncomplete(in: targetList)

    if targetList != nil {
        return sorted(items, by: order)
            .map { "\(calendarDot(hex: $0.list.color))\(formatListRow($0))" }
            .joined(separator: "\n")
    } else {
        var lines: [String] = []
        for (list, groupItems) in groupedByList(items, sortedBy: order) {
            let dot = calendarDot(hex: list.color)
            lines.append("\(dot)\(ANSI.bold(list.title))")
            for item in groupItems { lines.append("\(dot)\(formatListRow(item))") }
        }
        return lines.joined(separator: "\n")
    }
}
