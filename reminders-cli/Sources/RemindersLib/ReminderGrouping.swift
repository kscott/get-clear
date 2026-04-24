// ReminderGrouping.swift
// Groups a flat ReminderItem array by list name for the all-lists display.

public func groupedByList(
    _ items: [ReminderItem],
    sortedBy order: ReminderSortOrder
) -> [(header: String, items: [ReminderItem])] {
    let grouped = Dictionary(grouping: items, by: { $0.calendarTitle })
    return grouped.keys.sorted().map { header in
        (header: header, items: sorted(grouped[header]!, by: order))
    }
}
