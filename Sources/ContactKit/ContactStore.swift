// ContactStore.swift
//
// Protocol for contact backends and shared name/email/phone matching.

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

/// Match contacts against a query string. Searches name, email, company, and phone.
/// Returns results ranked by match quality; empty query returns an empty list.
public func matchContacts(_ query: String, in contacts: [Contact]) -> [Contact] {
    let q       = query.lowercased().trimmingCharacters(in: .whitespaces)
    guard !q.isEmpty else { return [] }
    let qDigits = String(q.filter(\.isNumber))

    func score(_ c: Contact) -> Int? {
        let name    = c.name.lowercased()
        let company = c.company.lowercased()

        if name == q                                                                              { return 0 }
        if name.hasPrefix(q)                                                                      { return 1 }
        if name.contains(q)                                                                       { return 2 }
        if c.emails.contains(where: { $0.value.lowercased().contains(q) })                       { return 3 }
        if company == q                                                                            { return 4 }
        if company.contains(q)                                                                    { return 5 }
        if !qDigits.isEmpty,
           c.phones.contains(where: { String($0.value.filter(\.isNumber)).contains(qDigits) })   { return 6 }
        return nil
    }

    return contacts.compactMap { c in score(c).map { (c, $0) } }
                   .sorted { $0.1 < $1.1 }
                   .map    { $0.0 }
}
