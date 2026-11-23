// MessageHelperRequestSpec.swift
//
// Tests for TextLib MessageHelperRequest — the send request survives the wire.

import Foundation
import Testing
import TextLib

@Suite("MessageHelperRequest coding")
struct MessageHelperRequestTests {
    @Test("a send request keeps its recipient and message through a JSON round trip")
    func roundTrips() throws {
        let request = MessageHelperRequest.send(query: "Alice Chen", message: "Running late — 10 min")
        #expect(try JSONDecoder().decode(MessageHelperRequest.self, from: JSONEncoder().encode(request)) == request)
    }
}
