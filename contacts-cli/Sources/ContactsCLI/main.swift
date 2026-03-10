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
      contacts open                       # Open the Contacts app
      contacts lists                      # Show all contact groups
      contacts list <group>               # Everyone in a group
      contacts export <group>             # Paste-ready "Name <email>, ..." string
      contacts search <query>             # Search name, email, phone, company
      contacts show <name>                # Full contact card
      contacts create <name> [company] [email E] [phone P] [note free text]
      contacts edit <name> [email E] [phone P] [--name "New Name"] [note free text]
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
    CNContactNoteKey as CNKeyDescriptor,
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
        note:    c.note
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
if cmd == "--version" || cmd == "-v" { print(version); exit(0) }
if cmd == "--help"    || cmd == "-h" { usage() }

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

    case "search":
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

    case "create":
        guard args.count > 1 else { fail("provide a contact name") }
        var remaining = Array(args.dropFirst())

        // Extract --name flag (not needed for create, name is positional)
        let name  = remaining[0]
        remaining = Array(remaining.dropFirst())

        // Parse keywords: email, phone, note (note must be last)
        var company = ""
        var email   = ""
        var phone   = ""
        var note    = ""

        let work = remaining.joined(separator: " ")

        if let r = work.range(of: #"\bnotes?\b"#, options: .regularExpression) {
            note = String(work[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            var trimmed = String(work[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)

            if let er = trimmed.range(of: #"\bemail\b"#, options: .regularExpression) {
                let after = String(trimmed[er.upperBound...]).trimmingCharacters(in: .whitespaces)
                email = after.components(separatedBy: " ").first ?? ""
                trimmed = String(trimmed[..<er.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
            if let pr = trimmed.range(of: #"\bphone\b"#, options: .regularExpression) {
                let after = String(trimmed[pr.upperBound...]).trimmingCharacters(in: .whitespaces)
                phone = after.components(separatedBy: " ").first ?? ""
                trimmed = String(trimmed[..<pr.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
            company = trimmed
        } else {
            var trimmed = work
            if let er = trimmed.range(of: #"\bemail\b"#, options: .regularExpression) {
                let after = String(trimmed[er.upperBound...]).trimmingCharacters(in: .whitespaces)
                email = after.components(separatedBy: " ").first ?? ""
                trimmed = String(trimmed[..<er.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
            if let pr = trimmed.range(of: #"\bphone\b"#, options: .regularExpression) {
                let after = String(trimmed[pr.upperBound...]).trimmingCharacters(in: .whitespaces)
                phone = after.components(separatedBy: " ").first ?? ""
                trimmed = String(trimmed[..<pr.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
            company = trimmed
        }

        let nameParts = name.components(separatedBy: " ")
        let contact   = CNMutableContact()
        contact.givenName       = nameParts.first ?? ""
        contact.familyName      = nameParts.count > 1 ? nameParts.dropFirst().joined(separator: " ") : ""
        contact.organizationName = company
        if !email.isEmpty {
            contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: email as NSString)]
        }
        if !phone.isEmpty {
            contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMain,
                                                   value: CNPhoneNumber(stringValue: phone))]
        }
        contact.note = note

        let request = CNSaveRequest()
        request.add(contact, toContainerWithIdentifier: nil)
        do {
            try store.execute(request)
            var parts = ["Created: \(name)"]
            if !email.isEmpty   { parts.append("email \(email)") }
            if !phone.isEmpty   { parts.append("phone \(phone)") }
            if !company.isEmpty { parts.append(company) }
            if !note.isEmpty    { parts.append("+ note") }
            print(parts.joined(separator: " · "))
        } catch {
            fail("Could not save contact: \(error.localizedDescription)")
        }
        semaphore.signal()

    case "edit":
        guard args.count > 1 else { fail("provide a contact name") }
        var editArgs = Array(args)
        var newName: String? = nil
        if let idx = editArgs.firstIndex(of: "--name"), idx + 1 < editArgs.count {
            newName = editArgs[idx + 1]
            editArgs.remove(at: idx + 1)
            editArgs.remove(at: idx)
        }

        let query = editArgs[1]
        guard let contact = cnContact(named: query) else { fail("Not found: \(query)") }
        let mutable = contact.mutableCopy() as! CNMutableContact

        var changes: [String] = []
        if let newName {
            let parts = newName.components(separatedBy: " ")
            mutable.givenName  = parts.first ?? ""
            mutable.familyName = parts.count > 1 ? parts.dropFirst().joined(separator: " ") : ""
            changes.append("name → \"\(newName)\"")
        }

        let work = editArgs.dropFirst(2).joined(separator: " ")
        if !work.isEmpty {
            if let r = work.range(of: #"\bnotes?\b"#, options: .regularExpression) {
                let noteVal = String(work[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                if noteVal.lowercased() == "none" {
                    mutable.note = ""
                    changes.append("note cleared")
                } else {
                    mutable.note = noteVal
                    changes.append("+ note")
                }
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

        guard !changes.isEmpty else { fail("nothing to change — specify email, phone, note, or --name") }

        let request = CNSaveRequest()
        request.update(mutable)
        do {
            try store.execute(request)
            print("Updated \"\(query)\": \(changes.joined(separator: ", "))")
        } catch {
            fail("Could not save: \(error.localizedDescription)")
        }
        semaphore.signal()

    default:
        usage()
    }
}

semaphore.wait()
