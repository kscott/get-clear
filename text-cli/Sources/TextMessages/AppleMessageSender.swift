// AppleMessageSender.swift
// MessageSender implementation via Messages.app and osascript.

import Foundation
import TextLib

public struct AppleMessageSender: MessageSender {
    public init() {}

    public func send(to recipient: String, message: String) async throws {
        let script = buildScript(recipient: recipient, message: message)
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("text-send-\(UUID().uuidString).applescript")
        try script.write(to: tmpURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments    = [tmpURL.path]
        let errPipe    = Pipe()
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
}
