// ContactStore.swift
//
// Protocol for contact backends, ContactStoreError, and store extension helpers.

import Foundation

public enum ContactStoreError: Error {
    case notFound(String)
    case ambiguous([Contact])
    case groupNotFound(String)
    case conflict
}

extension ContactStoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notFound(let q):      return "No contact found matching '\(q)'"
        case .ambiguous(let cs):    return "Multiple contacts match — \(cs.map(\.displayName).joined(separator: ", "))"
        case .groupNotFound(let n): return "No group named '\(n)'"
        case .conflict:             return "Could not save — contact may have been modified in another app"
        }
    }
}

public protocol ContactStore: Sendable {
    func fetchGroups() async throws -> [ContactGroup]
    func fetchContacts(in group: ContactGroup?) async throws -> [Contact]
    func add(_ draft: ContactDraft) async throws -> Contact
    func add(identifier: String, to group: ContactGroup) async throws
    func remove(identifier: String, from group: ContactGroup) async throws
    func update(identifier: String, changes: ContactChanges) async throws
    func rename(identifier: String, to newName: String) async throws
    func delete(identifier: String) async throws
}

public extension ContactStore {
    func contacts() async throws -> [Contact] {
        try await fetchContacts(in: nil)
    }

    func resolve(query: String) async throws -> Contact {
        let matches = matchContacts(query, in: try await fetchContacts(in: nil))
        switch matches.count {
        case 0:  throw ContactStoreError.notFound(query)
        case 1:  return matches[0]
        default: throw ContactStoreError.ambiguous(matches)
        }
    }

    func resolveGroup(named name: String) async throws -> ContactGroup {
        let groups = try await fetchGroups()
        guard let match = groups.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else {
            throw ContactStoreError.groupNotFound(name)
        }
        return match
    }
}

