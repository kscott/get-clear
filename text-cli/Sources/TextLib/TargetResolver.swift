// TargetResolver.swift
// Resolves a send target (phone, email, or contact name) to a display name and address.

import ContactKit

/// Resolve a raw query to a SendResult ready for Messages.app.
/// Handles direct phone numbers and emails without touching the contacts array.
/// Throws notFound or ambiguous when name resolution fails.
public func resolveTarget(query: String, contacts: [Contact]) throws -> SendResult {
    let q = query.trimmingCharacters(in: .whitespaces)
    let digits = q.filter(\.isNumber)

    if digits.count == 10 || digits.count == 11, !q.contains("@") {
        let address = normalizePhone(q)
        return SendResult(displayName: formatPhone(address), address: address)
    }

    if q.contains("@"), !q.contains(" ") {
        return SendResult(displayName: q, address: q)
    }

    let matches = matchContacts(q, in: contacts)
    guard !matches.isEmpty else { throw TextError.notFound(q) }
    if matches.count > 1 {
        let candidates = matches.prefix(5).map { c -> String in
            let addr = c.phones.first.map { formatPhone(normalizePhone($0.value)) }
                ?? c.emails.first?.value ?? ""
            return addr.isEmpty ? c.name : "\(c.name) (\(addr))"
        }.joined(separator: "\n  ")
        throw TextError.ambiguous("\"\(q)\" matches multiple contacts — be more specific:\n  \(candidates)")
    }
    let contact = matches[0]
    if let phone = contact.phones.first?.value {
        return SendResult(displayName: contact.name, address: normalizePhone(phone))
    }
    if let email = contact.emails.first?.value {
        return SendResult(displayName: contact.name, address: email)
    }
    throw TextError.notFound(q)
}

/// Returns true when the query requires a Contacts lookup.
/// Use this before fetching contacts — fetching triggers the system permission prompt.
public func requiresContactLookup(_ query: String) -> Bool {
    let q = query.trimmingCharacters(in: .whitespaces)
    let digits = q.filter(\.isNumber)
    if digits.count == 10 || digits.count == 11, !q.contains("@") { return false }
    if q.contains("@"), !q.contains(" ") { return false }
    return true
}
