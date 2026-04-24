// ListsHandler.swift

public func handleLists(store: any ReminderStore) async throws -> String {
    let lists = try await store.fetchLists()
    return lists.map(\.title).sorted().joined(separator: "\n")
}
