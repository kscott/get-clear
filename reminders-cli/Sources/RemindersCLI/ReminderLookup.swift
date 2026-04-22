// ReminderLookup.swift
//
// Resolves a single incomplete reminder by title from the EventKit store.
// Handles calendar scoping, fetch, exact-title matching, and multi-match disambiguation.

import EventKit
import GetClearKit

/// Validates args, resolves the reminder, and calls `action` with the matched reminder and title.
/// Handles error output and signals `semaphore` when done.
func withReminder(
    args: [String], cmd: String, store: EKEventStore, semaphore: DispatchSemaphore,
    action: @escaping (EKReminder, _ title: String) throws -> Void
) {
    guard args.count > 1 else { fail("provide a reminder title") }
    let title = args[1]
    let listName = args.count > 2 ? args[2] : nil
    resolveReminder(title: title, list: listName, cmd: cmd, store: store) { reminder in
        do {
            try action(reminder, title)
        } catch {
            fail("Operation failed: \(error.localizedDescription)")
        }
        semaphore.signal()
    }
}

/// Fetches the single incomplete reminder matching `title` (case-insensitive), optionally
/// scoped to `list`. Calls `fail()` if not found; prints disambiguation and exits if multiple
/// match. Calls `completion` with the matched reminder — caller signals the semaphore.
func resolveReminder(
    title: String,
    list: String?,
    cmd: String,
    store: EKEventStore,
    completion: @escaping (EKReminder) -> Void
) {
    let calendars: [EKCalendar]
    if let list {
        guard let cal = store.calendars(for: .reminder).first(where: { $0.title == list }) else {
            fail("List not found: \(list)")
        }
        calendars = [cal]
    } else {
        calendars = store.calendars(for: .reminder)
    }
    let predicate = store.predicateForIncompleteReminders(
        withDueDateStarting: nil, ending: nil, calendars: calendars)
    store.fetchReminders(matching: predicate) { reminders in
        let matches = (reminders ?? []).filter {
            ($0.title ?? "").caseInsensitiveCompare(title) == .orderedSame
        }
        guard !matches.isEmpty else {
            fail("Not found: \(title)\(list.map { " in \($0)" } ?? "")")
        }
        if matches.count > 1 {
            print("Multiple reminders named '\(title)':")
            for r in matches { print("  [\(r.calendar.title)]") }
            print("Add the list name to narrow: reminders \(cmd) \"\(title)\" \(matches[0].calendar.title)")
            exit(1)
        }
        completion(matches[0])
    }
}
