// OpenHandlerSpec.swift
// Tests for MailLib handleOpen.

import Foundation
import MailLib
import Testing

@Suite("handleOpen")
struct OpenHandlerTests {
    @Test("calls the opener with the config web app URL")
    func opensConfigWebAppURL() {
        var openedURL: URL?
        handleOpen(opener: { openedURL = $0 }, config: testConfig)
        #expect(openedURL == MailConfig.defaultWebAppURL)
    }

    @Test("calls the opener with a custom web app URL")
    func opensCustomWebAppURL() throws {
        let custom = try #require(URL(string: "https://mail.google.com"))
        let config = MailConfig(defaultFrom: "", identities: [], webAppURL: custom)
        var openedURL: URL?
        handleOpen(opener: { openedURL = $0 }, config: config)
        #expect(openedURL == custom)
    }
}
