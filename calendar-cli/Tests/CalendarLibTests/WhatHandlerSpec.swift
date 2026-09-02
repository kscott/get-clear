import CalendarLib
import Foundation
import Testing

@Suite("handleWhat")
struct WhatHandlerTests {
    @Test("throws for an unrecognised range string")
    func throwsForUnrecognisedRange() {
        #expect(throws: (any Error).self) { try handleWhat(args: ["what", "notarange"]) }
    }

    @Test("returns a non-empty string for today")
    func nonEmptyForToday() throws {
        let out = try handleWhat(args: ["what"])
        #expect(!out.isEmpty)
    }

    @Test("returns a non-empty string for a named range")
    func nonEmptyForNamedRange() throws {
        let out = try handleWhat(args: ["what", "7d"])
        #expect(!out.isEmpty)
    }
}
