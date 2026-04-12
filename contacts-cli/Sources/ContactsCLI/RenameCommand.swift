// RenameCommand.swift
//
// Renames a contact by updating its given and family name fields.

import Contacts
import ContactsLib
import GetClearKit

func handleRename(args: [String], store: CNContactStore, semaphore: DispatchSemaphore) {
    guard args.count > 2 else { fail("provide existing name and new name") }
    let oldName = args[1]; let newName = args[2]
    let all = allContacts(store: store, keysToFetch: keysToFetch)
    guard let contact = cnContact(named: oldName, in: all) else { fail("Not found: \(oldName)") }
    let mutable = contact.mutableCopy() as! CNMutableContact
    let parts = newName.components(separatedBy: " ")
    mutable.givenName  = parts.first ?? ""
    mutable.familyName = parts.count > 1 ? parts.dropFirst().joined(separator: " ") : ""
    let request = CNSaveRequest(); request.update(mutable)
    do {
        try store.execute(request)
        try? ActivityLog.write(tool: "contacts", cmd: "rename", desc: "\(oldName) → \(newName)", container: nil)
        print("Renamed: \"\(oldName)\" → \"\(newName)\"")
    } catch { fail("Could not rename: \(error.localizedDescription)") }
    semaphore.signal()
}
