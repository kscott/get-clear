// Matching.swift
//
// Pure contact matching and formatting logic.
// No Contacts framework dependency — lives in ContactsLib so it can be unit tested.

import Foundation

public struct ContactRecord {
    public let name: String
    public let emails: [(label: String, value: String)]
    public let phones: [(label: String, value: String)]
    public let company: String
    public let note: String

    public init(name: String,
                emails: [(label: String, value: String)],
                phones: [(label: String, value: String)],
                company: String,
                note: String) {
        self.name    = name
        self.emails  = emails
        self.phones  = phones
        self.company = company
        self.note    = note
    }

    /// Primary email — first in list, or empty string if none.
    public var primaryEmail: String { emails.first?.value ?? "" }

    /// Formatted as "Name <email>" for use in To/Cc fields.
    public var addressField: String {
        guard !primaryEmail.isEmpty else { return name }
        return "\(name) <\(primaryEmail)>"
    }
}

/// Find contacts matching a query string against name, email, phone, and company.
/// Returns results sorted by match quality: exact name first, then prefix, then substring.
public func matchContacts(_ query: String, in contacts: [ContactRecord]) -> [ContactRecord] {
    let q = query.lowercased().trimmingCharacters(in: .whitespaces)
    guard !q.isEmpty else { return contacts }

    func score(_ c: ContactRecord) -> Int? {
        let name    = c.name.lowercased()
        let company = c.company.lowercased()
        let emails  = c.emails.map { $0.value.lowercased() }
        let phones  = c.phones.map { $0.value.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression) }
        let qDigits = q.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)

        if name == q                                      { return 0 }
        if name.hasPrefix(q)                              { return 1 }
        if name.contains(q)                               { return 2 }
        if emails.contains(where: { $0.contains(q) })    { return 3 }
        if company == q                                   { return 4 }
        if company.contains(q)                            { return 5 }
        if !qDigits.isEmpty,
           phones.contains(where: { $0.contains(qDigits) }) { return 6 }
        return nil
    }

    return contacts.compactMap { c in score(c).map { (c, $0) } }
                   .sorted { $0.1 < $1.1 }
                   .map    { $0.0 }
}

/// Format a list of contacts as a paste-ready To/Cc string.
public func exportAddresses(_ contacts: [ContactRecord]) -> String {
    contacts.filter { !$0.primaryEmail.isEmpty }
            .map    { $0.addressField }
            .joined(separator: ", ")
}

/// Clean up a CNLabeledValue label for display (strips CNLabel prefix and underscores).
public func cleanLabel(_ raw: String) -> String {
    var s = raw
    if s.hasPrefix("_$!<") { s = String(s.dropFirst(4)) }
    if s.hasSuffix(">!$_") { s = String(s.dropLast(4)) }
    return s.lowercased()
}
