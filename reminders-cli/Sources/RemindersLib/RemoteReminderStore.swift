// RemoteReminderStore.swift
//
// A ReminderStore whose every method is a request to the Get Clear helper, which holds
// the Reminders permission (spec 018). Pure: the transport is injected.

import Foundation
import GetClearKit

public struct RemoteReminderStore: ReminderStore {
    private let caller: HelperCaller

    public init(transport: @escaping HelperTransport, appVersion: String) {
        caller = HelperCaller(
            tool: .reminders,
            appVersion: appVersion,
            transport: transport,
            decodeToolError: { try? HelperCoding.decode(ReminderStoreError.self, from: $0) }
        )
    }

    public func fetchLists() async throws -> [ReminderList] {
        try await caller.call(ReminderHelperRequest.fetchLists)
    }

    public func defaultList() async throws -> ReminderList {
        try await caller.call(ReminderHelperRequest.defaultList)
    }

    public func fetchIncomplete(in list: ReminderList?) async throws -> [ReminderItem] {
        try await caller.call(ReminderHelperRequest.fetchIncomplete(list: list))
    }

    public func fetchCompleted(in range: DateInterval) async throws -> [ReminderItem] {
        try await caller.call(ReminderHelperRequest.fetchCompleted(range: range))
    }

    public func add(_ item: ReminderItem) async throws -> ReminderItem {
        try await caller.call(ReminderHelperRequest.add(item))
    }

    public func update(identifier: String, changes: ReminderChanges) async throws {
        try await caller.perform(ReminderHelperRequest.update(identifier: identifier, changes: changes))
    }

    public func complete(identifier: String) async throws {
        try await caller.perform(ReminderHelperRequest.complete(identifier: identifier))
    }

    public func rename(identifier: String, to title: String) async throws {
        try await caller.perform(ReminderHelperRequest.rename(identifier: identifier, title: title))
    }

    public func delete(identifier: String) async throws {
        try await caller.perform(ReminderHelperRequest.delete(identifier: identifier))
    }
}
