// ShowCommand.swift
//
// Displays a full contact card for a named contact.

import Contacts
import ContactsLib
import GetClearKit

func handleShow(args: [String], store: CNContactStore, semaphore: DispatchSemaphore) {
    guard args.count > 1 else { fail("provide a contact name") }
    let query = args.dropFirst().joined(separator: " ")
    let all   = allContacts(store: store)
    guard let contact = cnContact(named: query, in: all) else { fail("Not found: \(query)") }
    for line in cardLines(for: toRecord(contact)) { print(line) }
    semaphore.signal()
}
