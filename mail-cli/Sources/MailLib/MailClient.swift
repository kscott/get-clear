// MailClient.swift
// Protocol for mail backends, with pure value types for outbound mail and search results.

import Foundation

public struct OutboundEmail: Equatable {
    public let from:             MailIdentity
    public let to:               [AddressEntry]
    public let cc:               [AddressEntry]
    public let subject:          String
    public let body:             String
    public let attachmentPaths:  [String]

    public init(from: MailIdentity, to: [AddressEntry], cc: [AddressEntry],
                subject: String, body: String, attachmentPaths: [String]) {
        self.from            = from
        self.to              = to
        self.cc              = cc
        self.subject         = subject
        self.body            = body
        self.attachmentPaths = attachmentPaths
    }
}

public struct EmailSummary: Equatable {
    public let subject:    String
    public let from:       String
    public let receivedAt: String

    public init(subject: String, from: String, receivedAt: String) {
        self.subject    = subject
        self.from       = from
        self.receivedAt = receivedAt
    }
}

public protocol MailClient: Sendable {
    func send(_ email: OutboundEmail) async throws
    func saveDraft(_ email: OutboundEmail) async throws
    func find(query: String, limit: Int) async throws -> [EmailSummary]
    func fetchIdentities() async throws -> [MailIdentity]
}
