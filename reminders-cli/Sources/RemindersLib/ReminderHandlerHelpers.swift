// ReminderHandlerHelpers.swift
// Internal helpers shared across handler files.

import Foundation
import GetClearKit

func storeError(title: String, list: ReminderList?, cmd: String, _ err: ReminderStoreError) -> ReminderHandlerError {
    switch err {
    case .notFound:
        return ReminderHandlerError(notFoundMessage(title: title, list: list?.title))
    case .ambiguous(let matches):
        return ReminderHandlerError(disambiguationMessage(title: title, matches: matches, cmd: cmd))
    }
}

func resolvedList(named name: String?, from lists: [ReminderList]) throws -> ReminderList? {
    guard let name else { return nil }
    guard let match = lists.first(where: { $0.title == name }) else {
        throw ReminderHandlerError("List not found: \(name)")
    }
    return match
}

func resolvedList(named name: String?, from store: any ReminderStore) async throws -> ReminderList? {
    try resolvedList(named: name, from: try await store.fetchLists())
}

func dateComponents(from pd: ParsedDate) -> DateComponents {
    let fields: Set<Calendar.Component> = pd.hasTime
        ? [.year, .month, .day, .hour, .minute] : [.year, .month, .day]
    return Calendar.current.dateComponents(fields, from: pd.date)
}
