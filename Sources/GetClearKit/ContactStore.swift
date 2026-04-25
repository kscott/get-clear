// ContactStore.swift
//
// Protocol for contact backends and shared name/email/phone matching.

import Foundation

public protocol ContactStore: Sendable {
    func contacts() async throws -> [Contact]
}

/// Match contacts against a query string. Searches name, email, company, and phone.
/// Returns results ranked by match quality; empty query returns all contacts unchanged.
public func matchContacts(_ query: String, in contacts: [Contact]) -> [Contact] {
    let q = query.lowercased().trimmingCharacters(in: .whitespaces)
    guard !q.isEmpty else { return contacts }

    func score(_ c: Contact) -> Int? {
        let name    = c.name.lowercased()
        let company = c.company.lowercased()
        let emails  = c.emails.map { $0.value.lowercased() }
        let phones  = c.phones.map { $0.value.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression) }
        let qDigits = q.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)

        if name == q                                         { return 0 }
        if name.hasPrefix(q)                                 { return 1 }
        if name.contains(q)                                  { return 2 }
        if emails.contains(where: { $0.contains(q) })       { return 3 }
        if company == q                                      { return 4 }
        if company.contains(q)                               { return 5 }
        if !qDigits.isEmpty,
           phones.contains(where: { $0.contains(qDigits) }) { return 6 }
        return nil
    }

    return contacts.compactMap { c in score(c).map { (c, $0) } }
                   .sorted { $0.1 < $1.1 }
                   .map    { $0.0 }
}
