// MailTestSupport.swift
// Shared test doubles for MailLibTests.

import Foundation
import MailLib

/// @unchecked Sendable: `MailClient` is `Sendable`, and this spy carries mutable
/// recording state. Safe because Swift Testing gives every `@Test` its own suite
/// instance (and thus its own spy) — no spy is ever shared across concurrent tests.
final class SpyMailClient: MailClient, @unchecked Sendable {
    var sentEmails: [OutboundEmail] = []
    var savedDrafts: [OutboundEmail] = []
    var findResults: [EmailSummary] = []
    var identities: [MailIdentity] = []
    var shouldThrow: Error?

    func send(_ email: OutboundEmail) async throws {
        if let e = shouldThrow { throw e }
        sentEmails.append(email)
    }

    func saveDraft(_ email: OutboundEmail) async throws {
        if let e = shouldThrow { throw e }
        savedDrafts.append(email)
    }

    func find(query: String, limit: Int) async throws -> [EmailSummary] {
        if let e = shouldThrow { throw e }
        return findResults
    }

    func fetchIdentities() async throws -> [MailIdentity] {
        if let e = shouldThrow { throw e }
        return identities
    }
}

let testIdentity = MailIdentity(id: "id1", email: "alice@example.com", name: "Alice")

let testConfig = MailConfig(
    defaultFrom: "alice@example.com",
    identities: [testIdentity]
)
