// OpenHandlerSpec.swift
// Tests for TextLib handleOpen.

import Foundation
import Testing
import TextLib

@Suite("handleOpen")
struct OpenHandlerTests {
    @Test("opens the Messages app URL")
    func opensMessagesAppURL() throws {
        var opened: URL?
        try handleOpen(args: ["open"], opener: { opened = $0 })
        #expect(opened?.path == "/System/Applications/Messages.app")
    }

    @Test("throws for a stray token after the command name and does not open")
    func throwsForStrayToken() {
        var opened: URL?
        #expect(throws: (any Error).self) {
            try handleOpen(args: ["open", "extra"], opener: { opened = $0 })
        }
        #expect(opened == nil)
    }
}
