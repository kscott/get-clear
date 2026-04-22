// ReminderLookup.swift
// Finds a single reminder by exact case-insensitive title match from a ReminderItem array.

public enum LookupResult: Equatable {
    case found(Int)
    case notFound
    case ambiguous([Int])
}

public func lookup(title: String, in items: [ReminderItem]) -> LookupResult {
    let indices = items.indices.filter {
        items[$0].title.caseInsensitiveCompare(title) == .orderedSame
    }
    switch indices.count {
    case 0:  return .notFound
    case 1:  return .found(indices[0])
    default: return .ambiguous(indices)
    }
}
