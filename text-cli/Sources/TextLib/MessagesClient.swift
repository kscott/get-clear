// MessagesClient.swift
// Pure AppleScript string builders — no process execution, fully testable.

import Foundation

// AppleScript has no escape sequences — split on " and rejoin with the built-in quote constant.
public func appleScriptLiteral(_ s: String) -> String {
    let parts = s.components(separatedBy: "\"")
    if parts.count == 1 { return "\"\(s)\"" }
    return parts.map { "\"\($0)\"" }.joined(separator: " & quote & ")
}

/// Build the AppleScript string that sends a message to a recipient.
public func buildScript(recipient: String, message: String) -> String {
    """
    tell application "Messages"
        send \(appleScriptLiteral(message)) to buddy \(appleScriptLiteral(recipient))
    end tell
    """
}
