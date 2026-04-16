// FindCommand.swift
//
// Finds contacts matching a name, email, phone, or company query.

import Contacts
import ContactsLib
import GetClearKit

func handleFind(args: [String], store: CNContactStore, semaphore: DispatchSemaphore) {
    guard args.count > 1 else { fail("provide a search query") }
    let query   = args.dropFirst().joined(separator: " ")
    let matched = matchContacts(query, in: allContacts(store: store).map(toRecord))
    if matched.isEmpty {
        print("No contacts matching '\(query)'")
    } else {
        for r in matched {
            let nameStr  = r.name.isEmpty ? r.company : r.name
            let emailStr = r.primaryEmail.isEmpty ? "" : " <\(r.primaryEmail)>"
            let compStr  = (!r.company.isEmpty && !r.name.isEmpty) ? " — \(r.company)" : ""
            print("  \(ANSI.bold(nameStr))\(emailStr)\(ANSI.dim(compStr))")
        }
    }
    semaphore.signal()
}
