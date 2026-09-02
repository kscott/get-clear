// WhatHandlerSpec.swift
// Tests for MailLib handleWhat.

import Foundation
import MailLib
import Testing

@Suite("handleWhat")
struct WhatHandlerTests {
    @Test("returns output for the default range")
    func defaultRange() {
        #expect(throws: Never.self) { try handleWhat(args: ["what"]) }
    }

    @Test("returns output for a named range")
    func namedRange() {
        #expect(throws: Never.self) { try handleWhat(args: ["what", "today"]) }
    }

    @Test("returns output for a non-today named range")
    func nonTodayNamedRange() {
        #expect(throws: Never.self) { try handleWhat(args: ["what", "yesterday"]) }
    }

    @Test("throws for an unrecognised range")
    func unrecognisedRange() {
        #expect(throws: (any Error).self) { try handleWhat(args: ["what", "notarange"]) }
    }
}
