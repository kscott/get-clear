// MessagesClient.swift
// Pure AppleScript string builders — no process execution, fully testable.

import Foundation

/// Escape a string for safe embedding in an AppleScript string literal.
///
/// AppleScript does not support escape sequences inside quoted strings.
/// Double quotes are handled by splitting on `"` and rejoining with the
/// built-in `quote` constant, which evaluates to a literal double-quote character.
///
/// Example: `say "hi"` → `"say " & quote & "hi" & quote & ""`
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
