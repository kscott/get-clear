// ListCommand.swift
//
// Lists contacts in a group, or exports them as a paste-ready address string.

import Contacts
import ContactsLib
import GetClearKit

func handleList(args: [String], store: CNContactStore, semaphore: DispatchSemaphore) {
    guard args.count > 1 else { fail("provide a group name") }
    let groupName = args.dropFirst().joined(separator: " ")
    guard let grp = group(named: groupName, store: store) else { fail("Group not found: \(groupName)") }
    let pred     = CNContact.predicateForContactsInGroup(withIdentifier: grp.identifier)
    let contacts = (try? store.unifiedContacts(matching: pred, keysToFetch: keysToFetch)) ?? []
    for r in contacts.map(toRecord).sorted(by: { $0.name < $1.name }) {
        let nameStr  = r.name.isEmpty ? r.company : r.name
        let emailStr = r.primaryEmail.isEmpty ? "(no email)" : r.primaryEmail
        print("  \(ANSI.bold(nameStr)) \(ANSI.dim("<\(emailStr)>"))")
    }
    semaphore.signal()
}

func handleExport(args: [String], store: CNContactStore, semaphore: DispatchSemaphore) {
    guard args.count > 1 else { fail("provide a group name") }
    let groupName = args.dropFirst().joined(separator: " ")
    guard let grp = group(named: groupName, store: store) else { fail("Group not found: \(groupName)") }
    let pred     = CNContact.predicateForContactsInGroup(withIdentifier: grp.identifier)
    let contacts = (try? store.unifiedContacts(matching: pred, keysToFetch: keysToFetch)) ?? []
    print(exportAddresses(contacts.map(toRecord).sorted { $0.name < $1.name }))
    semaphore.signal()
}
