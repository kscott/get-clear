// MailTestSupport.swift
// Shared test doubles for MailLibTests.

import Foundation
import MailLib

final class SpyMailClient: MailClient {
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

let testIdentity = MailIdentity(id: "id1", email: "ken@optikos.net", name: "Ken Scott")

let testConfig = MailConfig(
    defaultFrom: "ken@optikos.net",
    identities: [testIdentity]
)
