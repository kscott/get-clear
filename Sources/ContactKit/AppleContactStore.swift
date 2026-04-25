// AppleContactStore.swift
//
// Apple Contacts backend — loads contacts from CNContactStore and converts to suite Contact values.

import Foundation
import Contacts
import GetClearKit

private let keysToFetch: [CNKeyDescriptor] = [
    CNContactGivenNameKey        as CNKeyDescriptor,
    CNContactFamilyNameKey       as CNKeyDescriptor,
    CNContactOrganizationNameKey as CNKeyDescriptor,
    CNContactEmailAddressesKey   as CNKeyDescriptor,
    CNContactPhoneNumbersKey     as CNKeyDescriptor,
]

internal func cleanLabel(_ raw: String) -> String {
    var s = raw
    if s.hasPrefix("_$!<") { s = String(s.dropFirst(4)) }
    if s.hasSuffix(">!$_") { s = String(s.dropLast(4)) }
    return s.lowercased()
}

func toContact(_ c: CNContact) -> Contact {
    Contact(
        name:    [c.givenName, c.familyName].filter { !$0.isEmpty }.joined(separator: " "),
        emails:  c.emailAddresses.map { ContactField(label: cleanLabel($0.label ?? ""), value: $0.value as String) },
        phones:  c.phoneNumbers.map   { ContactField(label: cleanLabel($0.label ?? ""), value: $0.value.stringValue) },
        company: c.organizationName
    )
}

public final class AppleContactStore: ContactStore {
    private let cnStore: CNContactStore

    public init(store: CNContactStore = CNContactStore()) {
        self.cnStore = store
    }

    public func contacts() async throws -> [Contact] {
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        var results: [Contact] = []
        try cnStore.enumerateContacts(with: request) { c, _ in
            results.append(toContact(c))
        }
        return results
    }
}
