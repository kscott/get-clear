// ReminderGrouping.swift
// Groups a flat ReminderItem array by list for the all-lists display.

public func groupedByList(
    _ items: [ReminderItem],
    sortedBy order: ReminderSortOrder
) -> [(list: ReminderList, items: [ReminderItem])] {
    let grouped = Dictionary(grouping: items, by: { $0.list.title })
    return grouped.keys.sorted().map { title in
        let groupItems = grouped[title]!
        return (list: groupItems[0].list, items: sorted(groupItems, by: order))
    }
}
