// ArgumentParser.swift
//
// Maps a ParsedCommand (from GetClearKit's shared parser) onto the mail domain DTO.
// No framework dependencies — pure Swift, fully unit testable.

import GetClearKit

public struct ComposedMessage {
    public let to: String // unresolved recipient string
    public let cc: [String] // unresolved cc recipient strings
    public let subject: String
    public let body: String // raw text; caller handles file-path expansion
    public let attachments: [String]

    public init(to: String, cc: [String], subject: String, body: String, attachments: [String]) {
        self.to = to
        self.cc = cc
        self.subject = subject
        self.body = body
        self.attachments = attachments
    }
}

/// Maps a shared-parser result (per MailCommandShapes.send/.draft) onto the mail domain fields.
public func composeMessage(from parsed: ParsedCommand) -> ComposedMessage {
    ComposedMessage(
        to: parsed.identifiers[0],
        cc: parsed.repeatedValues["cc"] ?? [],
        subject: parsed.values["subject"] ?? "",
        body: parsed.trailingText ?? "",
        attachments: parsed.repeatedValues["attach"] ?? []
    )
}
