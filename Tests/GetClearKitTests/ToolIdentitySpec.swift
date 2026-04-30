// ToolIdentitySpec.swift
// Tests for ToolIdentity.

import GetClearKit
import Nimble
import Quick

final class ToolIdentitySpec: QuickSpec {
    override class func spec() {
        describe("ToolIdentity") {
            context("when built version matches suite version") {
                it("returns tool name, version, and summary") {
                    let id = ToolIdentity(tool: "get-clear", built: suiteVersion, summary: "Five tools for macOS. Claude as the conductor.")
                    expect(id.description) == "get-clear \(suiteVersion) — Five tools for macOS. Claude as the conductor."
                }
            }
            context("when built version differs from suite version") {
                it("includes suite version in parentheses") {
                    let id = ToolIdentity(tool: "reminders", built: "1.2.0", summary: "CLI for Apple Reminders")
                    expect(id.description) == "reminders 1.2.0 (Get Clear \(suiteVersion)) — CLI for Apple Reminders"
                }
            }
        }
    }
}
