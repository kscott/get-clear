// ReminderHandlerHelpers.swift
// Internal helpers shared across handler files.

func storeError(title: String, list: ReminderList?, cmd: String, _ err: ReminderStoreError) -> ReminderHandlerError {
    switch err {
    case .notFound:
        return ReminderHandlerError(notFoundMessage(title: title, list: list?.title))
    case .ambiguous(let matches):
        return ReminderHandlerError(disambiguationMessage(title: title, matches: matches, cmd: cmd))
    }
}

func resolvedList(named name: String?, from store: any ReminderStore) async throws -> ReminderList? {
    guard let name else { return nil }
    let allLists = try await store.fetchLists()
    guard let match = allLists.first(where: { $0.title == name }) else {
        throw ReminderHandlerError("List not found: \(name)")
    }
    return match
}
