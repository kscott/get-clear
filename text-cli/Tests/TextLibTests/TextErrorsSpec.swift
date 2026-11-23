// TextErrorsSpec.swift
// Tests for TextLib TextError — error descriptions.

import Foundation
import Testing
import TextLib

@Suite("TextError.errorDescription")
struct TextErrorsTests {
    @Test("formats sendFailed")
    func formatsSendFailed() {
        #expect(TextError.sendFailed("osascript error").errorDescription == "Send failed: osascript error")
    }

    @Test("formats notFound")
    func formatsNotFound() {
        #expect(TextError.notFound("Alice").errorDescription == "No contact found for \"Alice\"")
    }

    @Test("passes ambiguous message through unchanged")
    func passesAmbiguousThrough() {
        #expect(TextError.ambiguous("too many").errorDescription == "too many")
    }

    @Test("passes badArguments message through unchanged")
    func passesBadArgumentsThrough() {
        #expect(TextError.badArguments("provide a contact").errorDescription == "provide a contact")
    }
}

@Suite("TextError coding")
struct TextErrorCodingTests {
    @Test("each error keeps its message through a JSON round trip", arguments: [
        TextError.sendFailed("osascript error"), .notFound("Alice"), .ambiguous("too many"), .badArguments("x")
    ])
    func roundTrips(error: TextError) throws {
        #expect(try JSONDecoder().decode(TextError.self, from: JSONEncoder().encode(error)) == error)
    }
}
