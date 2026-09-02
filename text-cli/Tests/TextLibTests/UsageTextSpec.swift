// UsageTextSpec.swift
// Tests for TextLib usageText.

import Testing
import TextLib

@Suite("usageText")
struct UsageTextTests {
    @Test("contains the send command")
    func containsSendCommand() {
        #expect(usageText().contains("text send <contact> <message...>"))
    }

    @Test("contains the open command")
    func containsOpenCommand() {
        #expect(usageText().contains("text open"))
    }

    @Test("contains the feedback URL")
    func containsFeedbackURL() {
        #expect(usageText().contains("github.com/kscott/get-clear/issues"))
    }
}
