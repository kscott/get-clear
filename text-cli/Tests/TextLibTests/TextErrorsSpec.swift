// TextErrorsSpec.swift
// Tests for TextLib TextError — error descriptions.

import Nimble
import Quick
import TextLib

final class TextErrorsSpec: QuickSpec {
    override class func spec() {
        describe("TextError.errorDescription") {
            it("formats sendFailed") {
                expect(TextError.sendFailed("osascript error").errorDescription) == "Send failed: osascript error"
            }
            it("formats notFound") {
                expect(TextError.notFound("Alice").errorDescription) == "No contact found for \"Alice\""
            }
            it("passes ambiguous message through unchanged") {
                expect(TextError.ambiguous("too many").errorDescription) == "too many"
            }
            it("passes badArguments message through unchanged") {
                expect(TextError.badArguments("provide a contact").errorDescription) == "provide a contact"
            }
        }
    }
}
