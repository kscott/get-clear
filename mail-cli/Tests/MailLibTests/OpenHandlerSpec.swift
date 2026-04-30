// OpenHandlerSpec.swift
// Tests for MailLib handleOpen.

import Quick
import Nimble
import Foundation
import MailLib

final class MailOpenHandlerSpec: QuickSpec {
    override class func spec() {

        describe("handleOpen") {
            it("calls the opener with the config web app URL") {
                var openedURL: URL?
                handleOpen(opener: { openedURL = $0 }, config: testConfig)
                expect(openedURL) == MailConfig.defaultWebAppURL
            }
            it("calls the opener with a custom web app URL") {
                let custom = URL(string: "https://mail.google.com")!
                let config = MailConfig(defaultFrom: "", identities: [], webAppURL: custom)
                var openedURL: URL?
                handleOpen(opener: { openedURL = $0 }, config: config)
                expect(openedURL) == custom
            }
        }
    }
}
