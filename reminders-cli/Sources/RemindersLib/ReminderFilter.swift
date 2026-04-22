// ReminderFilter.swift
// Filters a ReminderItem array by case-insensitive substring match on title and notes.

/// Returns true if `item` matches `query` in its title or notes field.
public func matchesQuery(_ item: ReminderItem, query: String) -> Bool {
    let lower = query.lowercased()
    return item.title.lowercased().contains(lower) ||
           (item.notes ?? "").lowercased().contains(lower)
}

public func filtered(_ items: [ReminderItem], matching query: String) -> [ReminderItem] {
    items.filter { matchesQuery($0, query: query) }
}
