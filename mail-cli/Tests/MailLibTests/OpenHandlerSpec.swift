// OpenHandlerSpec.swift
// Tests for MailLib handleOpen.

import Foundation
import MailLib
import Testing

@Suite("handleOpen")
struct OpenHandlerTests {
    @Test("calls the opener with the config web app URL")
    func opensConfigWebAppURL() throws {
        var openedURL: URL?
        try handleOpen(args: ["open"], opener: { openedURL = $0 }, config: testConfig)
        #expect(openedURL == MailConfig.defaultWebAppURL)
    }

    @Test("calls the opener with a custom web app URL")
    func opensCustomWebAppURL() throws {
        let custom = try #require(URL(string: "https://mail.google.com"))
        let config = MailConfig(defaultFrom: "", identities: [], webAppURL: custom)
        var openedURL: URL?
        try handleOpen(args: ["open"], opener: { openedURL = $0 }, config: config)
        #expect(openedURL == custom)
    }

    @Test("throws for a stray token after the command name and does not open")
    func throwsForStrayToken() {
        var openedURL: URL?
        #expect(throws: (any Error).self) {
            try handleOpen(args: ["open", "extra"], opener: { openedURL = $0 }, config: testConfig)
        }
        #expect(openedURL == nil)
    }
}
