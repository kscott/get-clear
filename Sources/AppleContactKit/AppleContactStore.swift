// AppleContactStore.swift
//
// Apple Contacts backend — implements ContactStore using Contacts.framework.

import ContactKit
@preconcurrency import Contacts
import Foundation

private let keysToFetch: [CNKeyDescriptor] = [
    CNContactIdentifierKey as CNKeyDescriptor,
    CNContactGivenNameKey as CNKeyDescriptor,
    CNContactFamilyNameKey as CNKeyDescriptor,
    CNContactOrganizationNameKey as CNKeyDescriptor,
    CNContactEmailAddressesKey as CNKeyDescriptor,
    CNContactPhoneNumbersKey as CNKeyDescriptor
]

func toContact(_ c: CNContact) -> Contact {
    Contact(
        identifier: c.identifier,
        name: [c.givenName, c.familyName].filter { !$0.isEmpty }.joined(separator: " "),
        emails: c.emailAddresses.map { ContactField(label: cleanLabel($0.label ?? ""), value: $0.value as String) },
        phones: c.phoneNumbers.map { ContactField(label: cleanLabel($0.label ?? ""), value: $0.value.stringValue) },
        company: c.organizationName
    )
}

private func setName(_ name: String, on contact: CNMutableContact) {
    let parts = name.components(separatedBy: " ")
    contact.givenName = parts.first ?? ""
    contact.familyName = parts.count > 1 ? parts.dropFirst().joined(separator: " ") : ""
}

private func applyChanges(_ changes: ContactChanges, to contact: inout CNMutableContact) {
    switch changes.email {
    case .unchanged: break
    case .cleared:
        contact.emailAddresses = []
    case let .added(v):
        contact.emailAddresses.append(CNLabeledValue(label: CNLabelWork, value: v as NSString))
    case let .removed(v):
        contact.emailAddresses.removeAll { ($0.value as String).caseInsensitiveCompare(v) == .orderedSame }
    case let .replaced(from, to):
        if let idx = contact.emailAddresses.firstIndex(where: { ($0.value as String).caseInsensitiveCompare(from) == .orderedSame }) {
            let label = contact.emailAddresses[idx].label
            contact.emailAddresses[idx] = CNLabeledValue(label: label, value: to as NSString)
        } else {
            contact.emailAddresses.append(CNLabeledValue(label: CNLabelWork, value: to as NSString))
        }
    }

    switch changes.phone {
    case .unchanged: break
    case .cleared:
        contact.phoneNumbers = []
    case let .added(v):
        contact.phoneNumbers.append(CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: v)))
    case let .removed(v):
        contact.phoneNumbers.removeAll { $0.value.stringValue.caseInsensitiveCompare(v) == .orderedSame }
    case let .replaced(from, to):
        if let idx = contact.phoneNumbers.firstIndex(where: { $0.value.stringValue.caseInsensitiveCompare(from) == .orderedSame }) {
            let label = contact.phoneNumbers[idx].label
            contact.phoneNumbers[idx] = CNLabeledValue(label: label, value: CNPhoneNumber(stringValue: to))
        } else {
            contact.phoneNumbers.append(CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: to)))
        }
    }

    switch changes.company {
    case .unchanged: break
    case .cleared:
        contact.organizationName = ""
    case let .replaced(_, to):
        contact.organizationName = to
    case .added, .removed:
        break // parser never produces these for company
    }
}

public final class AppleContactStore: ContactStore {
    private let cnStore: CNContactStore

    public init(store: CNContactStore = CNContactStore()) {
        cnStore = store
    }

    public func fetchGroups() async throws -> [ContactGroup] {
        try cnStore.groups(matching: nil).map { ContactGroup(identifier: $0.identifier, name: $0.name) }
    }

    public func fetchContacts(in group: ContactGroup?) async throws -> [Contact] {
        if let group {
            let predicate = CNContact.predicateForContactsInGroup(withIdentifier: group.identifier)
            return try cnStore.unifiedContacts(matching: predicate, keysToFetch: keysToFetch).map(toContact)
        }
        let store = cnStore
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let request = CNContactFetchRequest(keysToFetch: keysToFetch)
                    var results: [Contact] = []
                    try store.enumerateContacts(with: request) { c, _ in results.append(toContact(c)) }
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func add(_ draft: ContactDraft) async throws -> Contact {
        let contact = CNMutableContact()
        setName(draft.name, on: contact)
        contact.emailAddresses = draft.emails.map {
            CNLabeledValue(label: ContactField.defaultEmailLabel, value: $0 as NSString)
        }
        contact.phoneNumbers = draft.phones.map {
            CNLabeledValue(label: ContactField.defaultPhoneLabel, value: CNPhoneNumber(stringValue: $0))
        }
        if let company = draft.company { contact.organizationName = company }
        let request = CNSaveRequest()
        request.add(contact, toContainerWithIdentifier: nil)
        try cnStore.execute(request)
        return toContact(contact)
    }

    public func add(identifier: String, to group: ContactGroup) async throws {
        let contact = try cnStore.unifiedContact(withIdentifier: identifier, keysToFetch: keysToFetch)
        let cnGroups = try cnStore.groups(matching: nil)
        guard let cnGroup = cnGroups.first(where: { $0.identifier == group.identifier }) else {
            throw ContactStoreError.groupNotFound(group.name)
        }
        let request = CNSaveRequest()
        request.addMember(contact, to: cnGroup)
        try cnStore.execute(request)
    }

    public func remove(identifier: String, from group: ContactGroup) async throws {
        let contact = try cnStore.unifiedContact(withIdentifier: identifier, keysToFetch: keysToFetch)
        let cnGroups = try cnStore.groups(matching: nil)
        guard let cnGroup = cnGroups.first(where: { $0.identifier == group.identifier }) else {
            throw ContactStoreError.groupNotFound(group.name)
        }
        let request = CNSaveRequest()
        request.removeMember(contact, from: cnGroup)
        try cnStore.execute(request)
    }

    public func update(identifier: String, changes: ContactChanges) async throws {
        let unified = try cnStore.unifiedContact(withIdentifier: identifier, keysToFetch: keysToFetch)
        let unifiedName = [unified.givenName, unified.familyName].filter { !$0.isEmpty }.joined(separator: " ")

        // Collect non-unified records for the CoreData 134092 multi-container retry.
        // Some contacts exist in multiple containers (e.g. iCloud + CardDAV). Try each
        // linked record until one saves. Suppress stderr — CoreData 134092 prints noise
        // asynchronously even after a failed save attempt.
        let nonUnifiedRequest = CNContactFetchRequest(keysToFetch: keysToFetch)
        nonUnifiedRequest.unifyResults = false
        var sources: [CNContact] = []
        try cnStore.enumerateContacts(with: nonUnifiedRequest) { c, _ in
            let name = [c.givenName, c.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            if name == unifiedName { sources.append(c) }
        }

        let savedStderrFd = dup(STDERR_FILENO)
        freopen("/dev/null", "w", stderr)
        var saved = false
        var lastError: Error?
        for source in sources {
            var m = source.mutableCopy() as! CNMutableContact
            applyChanges(changes, to: &m)
            let req = CNSaveRequest()
            req.update(m)
            do { try cnStore.execute(req)
                saved = true
                break
            } catch { lastError = error }
        }
        dup2(savedStderrFd, STDERR_FILENO)
        close(savedStderrFd)

        if !saved {
            if let err = lastError as NSError?, err.code == 134_092 {
                throw ContactStoreError.conflict
            }
            throw lastError ?? ContactStoreError.notFound(identifier)
        }
    }

    public func rename(identifier: String, to newName: String) async throws {
        let unified = try cnStore.unifiedContact(withIdentifier: identifier, keysToFetch: keysToFetch)
        let mutable = unified.mutableCopy() as! CNMutableContact
        setName(newName, on: mutable)
        let request = CNSaveRequest()
        request.update(mutable)
        try cnStore.execute(request)
    }

    public func delete(identifier: String) async throws {
        let unified = try cnStore.unifiedContact(withIdentifier: identifier, keysToFetch: keysToFetch)
        let mutable = unified.mutableCopy() as! CNMutableContact
        let request = CNSaveRequest()
        request.delete(mutable)
        try cnStore.execute(request)
    }
}
