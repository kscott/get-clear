// RemoveCommand.swift
//
// Removes a contact entirely, or removes a contact from a group.

import Contacts
import ContactsLib
import GetClearKit

func handleRemove(args: [String], store: CNContactStore, semaphore: DispatchSemaphore) {
    guard args.count > 1 else { fail("provide a contact name") }
    let name      = args[1]
    let remaining = Array(args.dropFirst(2))
    let all       = allContacts(store: store, keysToFetch: keysToFetch)

    if remaining.first == "from" {
        let groupName = Array(remaining.dropFirst()).joined(separator: " ")
        guard !groupName.isEmpty else { fail("provide a group name after 'from'") }
        guard let contact = cnContact(named: name, in: all) else { fail("Not found: \(name)") }
        guard let grp = group(named: groupName, store: store) else { fail("Group not found: \(groupName)") }
        let request = CNSaveRequest(); request.removeMember(contact, from: grp)
        do {
            try store.execute(request)
            try? ActivityLog.write(tool: "contacts", cmd: "remove", desc: "\(name) → \(grp.name)", container: grp.name)
            print("Removed \(name) from \(grp.name)")
        } catch { fail("Could not remove from group: \(error.localizedDescription)") }
    } else {
        guard let contact = cnContact(named: name, in: all) else { fail("Not found: \(name)") }
        let mutable = contact.mutableCopy() as! CNMutableContact
        let request = CNSaveRequest(); request.delete(mutable)
        do {
            try store.execute(request)
            try? ActivityLog.write(tool: "contacts", cmd: "remove", desc: name, container: nil)
            print("Removed: \(name)")
        } catch { fail("Could not remove contact: \(error.localizedDescription)") }
    }
    semaphore.signal()
}
