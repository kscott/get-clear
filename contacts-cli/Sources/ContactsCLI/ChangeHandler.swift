// ChangeHandler.swift
//
// Handles the change command: parses input, applies changes, saves with CoreData 134092 retry.

import Foundation
import Contacts
import ContactsLib
import GetClearKit

func handleChange(args: [String], store: CNContactStore, semaphore: DispatchSemaphore) {
    guard args.count > 1 else { fail("provide a contact name") }
    let query = args[1]
    let nonUnifiedRequest = CNContactFetchRequest(keysToFetch: keysToFetch)
    nonUnifiedRequest.unifyResults = false
    var candidates: [CNContact] = []
    try? store.enumerateContacts(with: nonUnifiedRequest) { c, _ in candidates.append(c) }
    let records = candidates.map(toRecord)
    guard let first = matchContacts(query, in: records).first else {
        fail("Not found: \(query)")
    }
    let changes: ContactChanges
    do { changes = try parseContactChanges(Array(args.dropFirst(2)).joined(separator: " ")) }
    catch { fail("nothing to change — specify [add|remove] email or [add|remove] phone") }

    let linkedCandidates = zip(candidates, records)
        .filter { $1.name == first.name }
        .map { $0.0 }
    var mutable = linkedCandidates[0].mutableCopy() as! CNMutableContact
    applyChanges(changes, to: &mutable)

    // Some contacts exist in multiple containers (e.g. iCloud + CardDAV). Try each linked
    // record until one saves. Suppress stderr for the remainder — CoreData 134092 prints
    // noise asynchronously even after a failed save.
    let savedStderrFd = dup(STDERR_FILENO)
    freopen("/dev/null", "w", stderr)
    var saved = false; var lastError: Error? = nil
    for source in linkedCandidates {
        let m = source.mutableCopy() as! CNMutableContact
        m.emailAddresses = mutable.emailAddresses
        m.phoneNumbers   = mutable.phoneNumbers
        let req = CNSaveRequest(); req.update(m)
        do { try store.execute(req); saved = true; break }
        catch { lastError = error }
    }

    func emit(_ msg: String) {
        let data = Data((msg + "\n").utf8)
        let fd = FileHandle(fileDescriptor: saved ? STDOUT_FILENO : savedStderrFd, closeOnDealloc: false)
        fd.write(data)
    }

    if saved {
        try? ActivityLog.write(tool: "contacts", cmd: "change", desc: query, container: nil)
        emit("Updated \"\(query)\": \(changes.descriptions.joined(separator: ", "))")
    } else if let err = lastError as NSError?, err.code == 134092 {
        emit("Error: Conflict saving contact — iCloud sync may be in progress, try again shortly")
        close(savedStderrFd); exit(1)
    } else {
        emit("Error: Could not save: \(lastError?.localizedDescription ?? "unknown error")")
        close(savedStderrFd); exit(1)
    }
    close(savedStderrFd)
    semaphore.signal()
}
