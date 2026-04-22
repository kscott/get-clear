// ListsCommand.swift
//
// Handler for the `lists` command — prints all reminder list names sorted alphabetically.

import EventKit

func handleLists(store: EKEventStore) async {
    print(store.calendars(for: .reminder).map { $0.title }.sorted().joined(separator: "\n"))
}
