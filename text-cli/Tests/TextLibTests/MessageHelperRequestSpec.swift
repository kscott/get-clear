// MessageHelperRequestSpec.swift
//
// Tests for TextLib MessageHelperRequest — the send request survives the wire.

import Foundation
import GetClearKit
import Testing
import TextLib

@Suite("MessageHelperRequest coding")
struct MessageHelperRequestTests {
    @Test("a send request keeps its recipient and message through a JSON round trip")
    func roundTrips() throws {
        let request = MessageHelperRequest.send(query: "Alice Chen", message: "Running late — 10 min")
        #expect(try JSONDecoder().decode(MessageHelperRequest.self, from: JSONEncoder().encode(request)) == request)
    }

    @Suite("requiredAccess")
    struct RequiredAccess {
        @Test("a name needs Contacts to look it up, then Messages")
        func name() {
            #expect(MessageHelperRequest.send(query: "Alice Chen", message: "hi").requiredAccess == [.contacts, .messages])
        }

        @Test("a phone number needs only Messages")
        func phone() {
            #expect(MessageHelperRequest.send(query: "303-555-1234", message: "hi").requiredAccess == [.messages])
        }
    }
}
