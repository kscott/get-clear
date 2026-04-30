// RecipientResolver.swift
// Resolve a recipient string to one or more email addresses.

import Foundation
import ContactKit

public struct AddressEntry: Equatable {
    public let name:  String
    public let email: String

    public init(name: String, email: String) {
        self.name  = name
        self.email = email
    }

    /// Formatted as "Name <email>" for use in To/Cc fields.
    public var formatted: String {
        name.isEmpty ? email : "\(name) <\(email)>"
    }
}

/// Returns true when the query requires a Contacts lookup (i.e. is not a raw email address).
public func requiresContactLookup(_ query: String) -> Bool {
    let q = query.trimmingCharacters(in: .whitespaces)
    return !(q.contains("@") && !q.contains(" "))
}

/// Resolve a recipient string to one or more AddressEntry values.
///
/// Resolution order:
///   1. Exact group name (case-insensitive) → all members
///   2. Raw email address (contains @) → direct, name looked up from contacts
///   3. Fuzzy contact match via matchContacts → primary email
///   4. No match → empty array
public func resolveRecipients(
    _ input:   String,
    groups:    [String: [AddressEntry]],
    contacts:  [Contact]
) -> [AddressEntry] {
    let q = input.trimmingCharacters(in: .whitespaces)

    // 1. Exact group name
    if let members = groups.first(where: { $0.key.caseInsensitiveCompare(q) == .orderedSame })?.value {
        return members
    }

    // 2. Raw email address — use exactly as given, look up name from contacts
    if q.contains("@") {
        let name = contacts.first(where: { c in
            c.emails.contains(where: { $0.value.caseInsensitiveCompare(q) == .orderedSame })
        })?.name ?? ""
        return [AddressEntry(name: name, email: q)]
    }

    // 3. Fuzzy contact match
    let matched = matchContacts(q, in: contacts)
    if let first = matched.first, let email = first.emails.first?.value {
        return [AddressEntry(name: first.name, email: email)]
    }

    return []
}

/// Resolve to and cc fields for a send operation.
public func buildRecipients(
    to:       [String],
    cc:       [String],
    groups:   [String: [AddressEntry]],
    contacts: [Contact]
) -> (to: [AddressEntry], cc: [AddressEntry]) {
    let toAddrs = to.flatMap { resolveRecipients($0, groups: groups, contacts: contacts) }
    let ccAddrs = cc.flatMap { resolveRecipients($0, groups: groups, contacts: contacts) }
    return (to: toAddrs, cc: ccAddrs)
}
