// MailErrorsSpec.swift
// Tests for MailLib MailError — error descriptions.

import Foundation
import MailLib
import Testing

@Suite("MailError.errorDescription")
struct MailErrorsTests {
    @Test("describes noToken")
    func describesNoToken() {
        #expect(MailError.noToken.errorDescription?.contains("setup") == true)
    }

    @Test("describes noConfig")
    func describesNoConfig() {
        #expect(MailError.noConfig.errorDescription?.contains("setup") == true)
    }

    @Test("describes noMatchingIdentity with the email")
    func describesNoMatchingIdentity() {
        #expect(MailError.noMatchingIdentity("x@y.com").errorDescription?.contains("x@y.com") == true)
    }

    @Test("describes sendFailed with the message")
    func describesSendFailed() {
        #expect(MailError.sendFailed("timeout").errorDescription?.contains("timeout") == true)
    }

    @Test("describes notFound with the query")
    func describesNotFound() {
        #expect(MailError.notFound("inbox").errorDescription?.contains("inbox") == true)
    }

    @Test("describes jmapError with the message")
    func describesJmapError() {
        #expect(MailError.jmapError("bad response").errorDescription?.contains("bad response") == true)
    }
}
