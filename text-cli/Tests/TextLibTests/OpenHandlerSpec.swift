// OpenHandlerSpec.swift
// Tests for TextLib handleOpen.

import Foundation
import Testing
import TextLib

@Suite("handleOpen")
struct OpenHandlerTests {
    @Test("opens the Messages app URL")
    func opensMessagesAppURL() {
        var opened: URL?
        handleOpen(opener: { opened = $0 })
        #expect(opened?.path == "/System/Applications/Messages.app")
    }
}
