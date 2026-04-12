// AddCommand.swift
//
// Creates a new contact or adds an existing contact to a group.

import Foundation
import Contacts
import ContactsLib
import GetClearKit

func handleAdd(args: [String], store: CNContactStore, semaphore: DispatchSemaphore) {
    guard args.count > 1 else { fail("provide a contact name") }
    let name      = args[1]
    let remaining = Array(args.dropFirst(2))

    if remaining.first == "to" {
        let groupName = Array(remaining.dropFirst()).joined(separator: " ")
        guard !groupName.isEmpty else { fail("provide a group name after 'to'") }
        let all = allContacts(store: store)
        guard let contact = cnContact(named: name, in: all) else { fail("Not found: \(name)") }
        guard let grp = group(named: groupName, store: store) else { fail("Group not found: \(groupName)") }
        let request = CNSaveRequest()
        request.addMember(contact, to: grp)
        do {
            try store.execute(request)
            try? ActivityLog.write(tool: "contacts", cmd: "add", desc: "\(name) → \(grp.name)", container: grp.name)
            print("Added \(name) to \(grp.name)")
        } catch { fail("Could not add to group: \(error.localizedDescription)") }
        semaphore.signal()
        return
    }

    let work = remaining.joined(separator: " ")
    var email = ""; var phone = ""; var trimmed = work
    if let r = trimmed.range(of: #"\bemail\b"#, options: .regularExpression) {
        email   = String(trimmed[r.upperBound...]).trimmingCharacters(in: .whitespaces).components(separatedBy: " ").first ?? ""
        trimmed = String(trimmed[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
    }
    if let r = trimmed.range(of: #"\bphone\b"#, options: .regularExpression) {
        phone = String(trimmed[r.upperBound...]).trimmingCharacters(in: .whitespaces).components(separatedBy: " ").first ?? ""
    }
    let nameParts = name.components(separatedBy: " ")
    let contact   = CNMutableContact()
    contact.givenName  = nameParts.first ?? ""
    contact.familyName = nameParts.count > 1 ? nameParts.dropFirst().joined(separator: " ") : ""
    if !email.isEmpty { contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: email as NSString)] }
    if !phone.isEmpty { contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMain, value: CNPhoneNumber(stringValue: phone))] }
    let request = CNSaveRequest()
    request.add(contact, toContainerWithIdentifier: nil)
    do {
        try store.execute(request)
        try? ActivityLog.write(tool: "contacts", cmd: "add", desc: name, container: nil)
        var parts = ["Added: \(name)"]
        if !email.isEmpty { parts.append("email \(email)") }
        if !phone.isEmpty { parts.append("phone \(phone)") }
        print(parts.joined(separator: " · "))
    } catch { fail("Could not save contact: \(error.localizedDescription)") }
    semaphore.signal()
}
