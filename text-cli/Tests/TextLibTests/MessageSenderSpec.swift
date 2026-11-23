// MessageSenderSpec.swift
//
// Tests for TextLib MessageSender.swift — the SendResult value type.

import Foundation
import Testing
import TextLib

@Suite("SendResult coding")
struct SendResultCodingTests {
    @Test("a send result survives a JSON round trip")
    func roundTrips() throws {
        let result = SendResult(displayName: "Alice Chen", address: "+15551234567")
        #expect(try JSONDecoder().decode(SendResult.self, from: JSONEncoder().encode(result)) == result)
    }
}
