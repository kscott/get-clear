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
        let contacts = requiresContactLookup(query) ? try await contactStore.contacts() : []
        let target   = try resolveTarget(query: query, contacts: contacts)
        try sendViaMessages(to: target.address, message: message)
        return target
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
