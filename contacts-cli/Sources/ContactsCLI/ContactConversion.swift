// ContactConversion.swift
//
// Converts CNContact framework objects to ContactRecord plain-data values, and provides
// shared store helpers used across command handlers.

import Contacts
import ContactsLib

let keysToFetch: [CNKeyDescriptor] = [
    CNContactGivenNameKey as CNKeyDescriptor,
    CNContactFamilyNameKey as CNKeyDescriptor,
    CNContactOrganizationNameKey as CNKeyDescriptor,
    CNContactEmailAddressesKey as CNKeyDescriptor,
    CNContactPhoneNumbersKey as CNKeyDescriptor,
]

func toRecord(_ c: CNContact) -> ContactRecord {
    ContactRecord(
        name:    [c.givenName, c.familyName].filter { !$0.isEmpty }.joined(separator: " "),
        emails:  c.emailAddresses.map { (cleanLabel($0.label ?? ""), $0.value as String) },
        phones:  c.phoneNumbers.map   { (cleanLabel($0.label ?? ""), $0.value.stringValue) },
        company: c.organizationName
    )
}

func cnContact(named query: String, in contacts: [CNContact]) -> CNContact? {
    let records = contacts.map(toRecord)
    guard let first = matchContacts(query, in: records).first else { return nil }
    return zip(contacts, records).first { $1.name == first.name }?.0
}

func allContacts(store: CNContactStore) -> [CNContact] {
    let request = CNContactFetchRequest(keysToFetch: keysToFetch)
    var results: [CNContact] = []
    try? store.enumerateContacts(with: request) { contact, _ in results.append(contact) }
    return results
}

func group(named groupName: String, store: CNContactStore) -> CNGroup? {
    ((try? store.groups(matching: nil)) ?? []).first {
        $0.name.caseInsensitiveCompare(groupName) == .orderedSame
    }
}

func applyChanges(_ changes: ContactChanges, to contact: inout CNMutableContact) {
    switch changes.email {
    case .unchanged: break
    case .cleared:
        contact.emailAddresses = []
    case .replaced(let v):
        contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: v as NSString)]
    case .added(let v):
        contact.emailAddresses.append(CNLabeledValue(label: CNLabelWork, value: v as NSString))
    case .removed(let v):
        contact.emailAddresses.removeAll {
            ($0.value as String).caseInsensitiveCompare(v) == .orderedSame
        }
    }
    switch changes.phone {
    case .unchanged: break
    case .cleared:
        contact.phoneNumbers = []
    case .replaced(let v):
        contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMain,
                                               value: CNPhoneNumber(stringValue: v))]
    case .added(let v):
        contact.phoneNumbers.append(CNLabeledValue(label: CNLabelPhoneNumberMain,
                                                   value: CNPhoneNumber(stringValue: v)))
    case .removed(let v):
        contact.phoneNumbers.removeAll {
            $0.value.stringValue.caseInsensitiveCompare(v) == .orderedSame
        }
    }
}
