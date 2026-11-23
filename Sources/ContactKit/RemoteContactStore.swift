// RemoteContactStore.swift
//
// A ContactStore whose every method is a request to the Get Clear helper, which holds
// the Contacts permission (spec 018). Pure: the transport is injected.

import Foundation
import GetClearKit

public struct RemoteContactStore: ContactStore {
    private let caller: HelperCaller

    public init(transport: @escaping HelperTransport, appVersion: String) {
        caller = HelperCaller(
            tool: .contacts,
            appVersion: appVersion,
            transport: transport,
            decodeToolError: { try? HelperCoding.decode(ContactStoreError.self, from: $0) }
        )
    }

    public func fetchGroups() async throws -> [ContactGroup] {
        try await caller.call(ContactHelperRequest.fetchGroups)
    }

    public func fetchContacts(in group: ContactGroup?) async throws -> [Contact] {
        try await caller.call(ContactHelperRequest.fetchContacts(group: group))
    }

    public func add(_ draft: ContactDraft) async throws -> Contact {
        try await caller.call(ContactHelperRequest.add(draft))
    }

    public func add(identifier: String, to group: ContactGroup) async throws {
        try await caller.perform(ContactHelperRequest.addToGroup(identifier: identifier, group: group))
    }

    public func remove(identifier: String, from group: ContactGroup) async throws {
        try await caller.perform(ContactHelperRequest.removeFromGroup(identifier: identifier, group: group))
    }

    public func update(identifier: String, changes: ContactChanges) async throws {
        try await caller.perform(ContactHelperRequest.update(identifier: identifier, changes: changes))
    }

    public func rename(identifier: String, to newName: String) async throws {
        try await caller.perform(ContactHelperRequest.rename(identifier: identifier, newName: newName))
    }

    public func delete(identifier: String) async throws {
        try await caller.perform(ContactHelperRequest.delete(identifier: identifier))
    }
}
