// MailErrorsSpec.swift
// Tests for MailLib MailError — error descriptions.

import Quick
import Nimble
import Foundation
import MailLib

final class MailErrorsSpec: QuickSpec {
    override class func spec() {
        describe("MailError.errorDescription") {
            it("describes noToken") {
                expect(MailError.noToken.errorDescription).to(contain("setup"))
            }
            it("describes noConfig") {
                expect(MailError.noConfig.errorDescription).to(contain("setup"))
            }
            it("describes noMatchingIdentity with the email") {
                expect(MailError.noMatchingIdentity("x@y.com").errorDescription).to(contain("x@y.com"))
            }
            it("describes sendFailed with the message") {
                expect(MailError.sendFailed("timeout").errorDescription).to(contain("timeout"))
            }
            it("describes notFound with the query") {
                expect(MailError.notFound("inbox").errorDescription).to(contain("inbox"))
            }
            it("describes jmapError with the message") {
                expect(MailError.jmapError("bad response").errorDescription).to(contain("bad response"))
            }
        }
    }
}
