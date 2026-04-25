// AppleMessageSender.swift
// Apple Messages backend: contact resolution via ContactKit, osascript dispatch.

import Foundation
import ContactKit
import TextLib

public struct AppleMessageSender: MessageSender {
    private let contactStore: any ContactStore

    public init(contacts: any ContactStore) {
        self.contactStore = contacts
    }

    public func send(to query: String, message: String) async throws -> SendResult {
        let q = query.trimmingCharacters(in: .whitespaces)

        // Direct phone number — skip contact lookup
        let digits = q.filter { $0.isNumber }
        if (digits.count == 10 || digits.count == 11) && !q.contains("@") {
            let address = normalizePhone(q)
            try sendViaMessages(to: address, message: message)
            return SendResult(displayName: formatPhone(address), address: address)
        }

        // Direct email — skip contact lookup
        if q.contains("@") && !q.contains(" ") {
            try sendViaMessages(to: q, message: message)
            return SendResult(displayName: q, address: q)
        }

        // Name/partial match via ContactStore
        let all     = try await contactStore.contacts()
        let matches = matchContacts(q, in: all)
        guard let contact = matches.first else { throw TextError.notFound(q) }

        let address: String
        if let phone = contact.phones.first?.value {
            address = normalizePhone(phone)
        } else if let email = contact.emails.first?.value {
            address = email
        } else {
            throw TextError.notFound(q)
        }

        try sendViaMessages(to: address, message: message)
        return SendResult(displayName: contact.name, address: address)
    }
}

private func sendViaMessages(to address: String, message: String) throws {
    let script = buildScript(recipient: address, message: message)
    let tmpURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("text-send-\(UUID().uuidString).applescript")
    try script.write(to: tmpURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tmpURL) }

    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    p.arguments     = [tmpURL.path]
    let errPipe     = Pipe()
    p.standardError = errPipe
    try p.run()
    p.waitUntilExit()

    guard p.terminationStatus == 0 else {
        let data   = errPipe.fileHandleForReading.readDataToEndOfFile()
        let errMsg = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "AppleScript error"
        throw TextError.sendFailed(errMsg)
    }
}
