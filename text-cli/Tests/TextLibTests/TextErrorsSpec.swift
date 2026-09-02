// TextErrorsSpec.swift
// Tests for TextLib TextError — error descriptions.

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
