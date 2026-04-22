// ReminderFetcher.swift
// Bridges the EventKit fetchReminders callback into an async call site.

import EventKit

func fetchReminders(matching predicate: NSPredicate, from store: EKEventStore) async -> [EKReminder] {
    await withCheckedContinuation { continuation in
        store.fetchReminders(matching: predicate) { continuation.resume(returning: $0 ?? []) }
    }
}
