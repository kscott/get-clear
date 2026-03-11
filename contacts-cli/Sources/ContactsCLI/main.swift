// main.swift
//
// Entry point for contacts-bin executable.
// Handles argument parsing and all Contacts/AppKit interactions.
// Matching and formatting logic delegated to ContactsLib for unit testing.

import Foundation
import AppKit
import Contacts
import ContactsLib

let version = "1.0.0"

let store     = CNContactStore()
let semaphore = DispatchSemaphore(value: 0)
let args      = Array(CommandLine.arguments.dropFirst())

func fail(_ msg: String) -> Never {
    fputs("Error: \(msg)\n", stderr)
    exit(1)
}

func usage() -> Never {
    print("""
    contacts \(version) — CLI for Apple Contacts

    Usage:
      contacts open                             # Open the Contacts app
      contacts lists                            # Show all contact groups
      contacts list <group>                     # Everyone in a group
      contacts export <group>                   # Paste-ready "Name <email>, ..." string
      contacts find <query>                     # Find by name, email, phone, company
      contacts show <name>                      # Full contact card
      contacts add <name> [email E] [phone P] [note free text]
      contacts add <name> to <group>            # Add contact to a group
      contacts change <name> [email E] [phone P] [note free text]
      contacts rename <name> <new-name>         # Rename a contact
      contacts remove <name>                    # Remove a contact
      contacts remove <name> from <group>       # Remove contact from a group

    Feedback: https://github.com/kscott/get-clear/issues
    """)
    exit(0)
}

// MARK: - Helpers

let keysToFetch: [CNKeyDescriptor] = [
    CNContactGivenNameKey as CNKeyDescriptor,
    CNContactFamilyNameKey as CNKeyDescriptor,
    CNContactOrganizationNameKey as CNKeyDescriptor,
    CNContactEmailAddressesKey as CNKeyDescriptor,
    CNContactPhoneNumbersKey as CNKeyDescriptor,
    // CNContactNoteKey requires com.apple.developer.contacts.notes entitlement (macOS 13+)
    // Entitlement requires signed + notarized binary — see contacts #12, #13 and get-clear #8
]

func allContacts() -> [CNContact] {
    let request = CNContactFetchRequest(keysToFetch: keysToFetch)
    var results: [CNContact] = []
    try? store.enumerateContacts(with: request) { contact, _ in results.append(contact) }
    return results
}

func toRecord(_ c: CNContact) -> ContactRecord {
    ContactRecord(
        name:    [c.givenName, c.familyName].filter { !$0.isEmpty }.joined(separator: " "),
        emails:  c.emailAddresses.map { (cleanLabel($0.label ?? ""), $0.value as String) },
        phones:  c.phoneNumbers.map   { (cleanLabel($0.label ?? ""), $0.value.stringValue) },
        company: c.organizationName,
        note:    ""  // note requires signed + notarized binary — see contacts #12, #13
    )
}

func cnContact(named query: String) -> CNContact? {
    let records = allContacts()
    let matched = matchContacts(query, in: records.map(toRecord))
    guard let first = matched.first else { return nil }
    return records.first { toRecord($0).name == first.name }
}

func printCard(_ c: CNContact) {
    let r = toRecord(c)
    let name = r.name.isEmpty ? c.organizationName : r.name
    print(name)
    if !r.company.isEmpty && !r.name.isEmpty { print("  Company:  \(r.company)") }
    for (label, value) in r.emails { print("  Email:    \(value)\(label.isEmpty ? "" : " (\(label))")") }
    for (label, value) in r.phones { print("  Phone:    \(value)\(label.isEmpty ? "" : " (\(label))")") }
    if !r.note.isEmpty { print("  Note:     \(r.note)") }
}

// MARK: - Dispatch

guard let cmd = args.first else { usage() }
if cmd == "--version" || cmd == "-v" || cmd == "version" { print(version); exit(0) }
if cmd == "--help"    || cmd == "-h" || cmd == "help"    { usage() }

store.requestAccess(for: .contacts) { granted, _ in
    guard granted else { fail("Contacts access denied") }

    switch cmd {

    case "open":
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Contacts.app"))
        semaphore.signal()

    case "lists":
        let groups = (try? store.groups(matching: nil)) ?? []
        for g in groups.sorted(by: { $0.name < $1.name }) { print(g.name) }
        semaphore.signal()

    case "list":
        guard args.count > 1 else { fail("provide a group name") }
        let groupName = args.dropFirst().joined(separator: " ")
        guard let group = ((try? store.groups(matching: nil)) ?? []).first(where: {
            $0.name.caseInsensitiveCompare(groupName) == .orderedSame
        }) else { fail("Group not found: \(groupName)") }

        let pred     = CNContact.predicateForContactsInGroup(withIdentifier: group.identifier)
        let contacts = (try? store.unifiedContacts(matching: pred, keysToFetch: keysToFetch)) ?? []
        for c in contacts.sorted(by: { toRecord($0).name < toRecord($1).name }) {
            let r = toRecord(c)
            let nameStr = r.name.isEmpty ? c.organizationName : r.name
            let emailStr = r.primaryEmail.isEmpty ? "(no email)" : r.primaryEmail
            print("  \(nameStr) <\(emailStr)>")
        }
        semaphore.signal()

    case "export":
        guard args.count > 1 else { fail("provide a group name") }
        let groupName = args.dropFirst().joined(separator: " ")
        guard let group = ((try? store.groups(matching: nil)) ?? []).first(where: {
            $0.name.caseInsensitiveCompare(groupName) == .orderedSame
        }) else { fail("Group not found: \(groupName)") }

        let pred     = CNContact.predicateForContactsInGroup(withIdentifier: group.identifier)
        let contacts = (try? store.unifiedContacts(matching: pred, keysToFetch: keysToFetch)) ?? []
        let records  = contacts.map(toRecord).sorted { $0.name < $1.name }
        print(exportAddresses(records))
        semaphore.signal()

    case "find":
        guard args.count > 1 else { fail("provide a search query") }
        let query   = args.dropFirst().joined(separator: " ")
        let records = allContacts().map(toRecord)
        let matched = matchContacts(query, in: records)
        if matched.isEmpty {
            print("No contacts matching '\(query)'")
        } else {
            for r in matched {
                let nameStr  = r.name.isEmpty ? r.company : r.name
                let emailStr = r.primaryEmail.isEmpty ? "" : " <\(r.primaryEmail)>"
                let compStr  = (!r.company.isEmpty && !r.name.isEmpty) ? " — \(r.company)" : ""
                print("  \(nameStr)\(emailStr)\(compStr)")
            }
        }
        semaphore.signal()

    case "show":
        guard args.count > 1 else { fail("provide a contact name") }
        let query = args.dropFirst().joined(separator: " ")
        guard let contact = cnContact(named: query) else { fail("Not found: \(query)") }
        printCard(contact)
        semaphore.signal()

    case "add":
        guard args.count > 1 else { fail("provide a contact name") }
        let name      = args[1]
        let remaining = Array(args.dropFirst(2))

        // "add <name> to <group>" — group membership
        if remaining.first == "to" {
            let groupName = Array(remaining.dropFirst()).joined(separator: " ")
            guard !groupName.isEmpty else { fail("provide a group name after 'to'") }
            guard let contact = cnContact(named: name) else { fail("Not found: \(name)") }
            guard let group = ((try? store.groups(matching: nil)) ?? []).first(where: {
                $0.name.caseInsensitiveCompare(groupName) == .orderedSame
            }) else { fail("Group not found: \(groupName)") }
            let request = CNSaveRequest()
            request.addMember(contact, to: group)
            do {
                try store.execute(request)
                print("Added \(name) to \(group.name)")
            } catch {
                fail("Could not add to group: \(error.localizedDescription)")
            }
            semaphore.signal()
            return
        }

        // "add <name> [email E] [phone P] [note text]" — create contact
        var email = ""
        var phone = ""
        var note  = ""
        let work  = remaining.joined(separator: " ")

        var trimmed = work
        if let r = trimmed.range(of: #"\bnotes?\b"#, options: .regularExpression) {
            note    = String(trimmed[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            trimmed = String(trimmed[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        if let r = trimmed.range(of: #"\bemail\b"#, options: .regularExpression) {
            email   = String(trimmed[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                        .components(separatedBy: " ").first ?? ""
            trimmed = String(trimmed[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        if let r = trimmed.range(of: #"\bphone\b"#, options: .regularExpression) {
            phone   = String(trimmed[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                        .components(separatedBy: " ").first ?? ""
        }

        let nameParts = name.components(separatedBy: " ")
        let contact   = CNMutableContact()
        contact.givenName  = nameParts.first ?? ""
        contact.familyName = nameParts.count > 1 ? nameParts.dropFirst().joined(separator: " ") : ""
        if !email.isEmpty {
            contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: email as NSString)]
        }
        if !phone.isEmpty {
            contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMain,
                                                   value: CNPhoneNumber(stringValue: phone))]
        }
        // note write requires signed + notarized binary — see contacts #12, #13

        let request = CNSaveRequest()
        request.add(contact, toContainerWithIdentifier: nil)
        do {
            try store.execute(request)
            var parts = ["Added: \(name)"]
            if !email.isEmpty { parts.append("email \(email)") }
            if !phone.isEmpty { parts.append("phone \(phone)") }
            print(parts.joined(separator: " · "))
        } catch {
            fail("Could not save contact: \(error.localizedDescription)")
        }
        semaphore.signal()

    case "change":
        guard args.count > 1 else { fail("provide a contact name") }
        let query = args[1]
        guard let contact = cnContact(named: query) else { fail("Not found: \(query)") }
        let mutable = contact.mutableCopy() as! CNMutableContact

        var changes: [String] = []
        let work = Array(args.dropFirst(2)).joined(separator: " ")
        if !work.isEmpty {
            if let _ = work.range(of: #"\bnotes?\b"#, options: .regularExpression) {
                // note write requires signed + notarized binary — see contacts #12, #13
                changes.append("note (skipped — requires notarized binary)")
            }
            if let r = work.range(of: #"\bemail\b"#, options: .regularExpression) {
                let val = String(work[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                            .components(separatedBy: " ").first ?? ""
                if val.lowercased() == "none" {
                    mutable.emailAddresses = []
                    changes.append("email cleared")
                } else {
                    mutable.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: val as NSString)]
                    changes.append("email → \(val)")
                }
            }
            if let r = work.range(of: #"\bphone\b"#, options: .regularExpression) {
                let val = String(work[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                            .components(separatedBy: " ").first ?? ""
                if val.lowercased() == "none" {
                    mutable.phoneNumbers = []
                    changes.append("phone cleared")
                } else {
                    mutable.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMain,
                                                           value: CNPhoneNumber(stringValue: val))]
                    changes.append("phone → \(val)")
                }
            }
        }

        guard !changes.isEmpty else { fail("nothing to change — specify email, phone, or note") }

        let request = CNSaveRequest()
        request.update(mutable)
        do {
            try store.execute(request)
            print("Updated \"\(query)\": \(changes.joined(separator: ", "))")
        } catch {
            fail("Could not save: \(error.localizedDescription)")
        }
        semaphore.signal()

    case "rename":
        guard args.count > 2 else { fail("provide existing name and new name") }
        let oldName = args[1]
        let newName = args[2]
        guard let contact = cnContact(named: oldName) else { fail("Not found: \(oldName)") }
        let mutable = contact.mutableCopy() as! CNMutableContact
        let parts = newName.components(separatedBy: " ")
        mutable.givenName  = parts.first ?? ""
        mutable.familyName = parts.count > 1 ? parts.dropFirst().joined(separator: " ") : ""
        let renameRequest = CNSaveRequest()
        renameRequest.update(mutable)
        do {
            try store.execute(renameRequest)
            print("Renamed: \"\(oldName)\" → \"\(newName)\"")
        } catch {
            fail("Could not rename: \(error.localizedDescription)")
        }
        semaphore.signal()

    case "remove":
        guard args.count > 1 else { fail("provide a contact name") }
        let name      = args[1]
        let remaining = Array(args.dropFirst(2))

        // "remove <name> from <group>" — group membership
        if remaining.first == "from" {
            let groupName = Array(remaining.dropFirst()).joined(separator: " ")
            guard !groupName.isEmpty else { fail("provide a group name after 'from'") }
            guard let contact = cnContact(named: name) else { fail("Not found: \(name)") }
            guard let group = ((try? store.groups(matching: nil)) ?? []).first(where: {
                $0.name.caseInsensitiveCompare(groupName) == .orderedSame
            }) else { fail("Group not found: \(groupName)") }
            let request = CNSaveRequest()
            request.removeMember(contact, from: group)
            do {
                try store.execute(request)
                print("Removed \(name) from \(group.name)")
            } catch {
                fail("Could not remove from group: \(error.localizedDescription)")
            }
        } else {
            // "remove <name>" — delete contact
            guard let contact = cnContact(named: name) else { fail("Not found: \(name)") }
            let mutable = contact.mutableCopy() as! CNMutableContact
            let request = CNSaveRequest()
            request.delete(mutable)
            do {
                try store.execute(request)
                print("Removed: \(name)")
            } catch {
                fail("Could not remove contact: \(error.localizedDescription)")
            }
        }
        semaphore.signal()

    default:
        usage()
    }
}

semaphore.wait()
