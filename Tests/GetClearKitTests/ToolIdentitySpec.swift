// ToolIdentitySpec.swift
// Tests for ToolIdentity.

import GetClearKit
import Testing

@Suite("ToolIdentity")
struct ToolIdentityTests {
    @Suite("when built version matches suite version")
    struct MatchingVersion {
        @Test("returns tool name, version, and summary")
        func returnsIdentity() {
            let id = ToolIdentity(tool: "get-clear", built: suiteVersion,
                                  summary: "Five tools for macOS. Claude as the conductor.")
            #expect(id.description == "get-clear \(suiteVersion) — Five tools for macOS. Claude as the conductor.")
        }
    }

    @Suite("when built version differs from suite version")
    struct DifferingVersion {
        @Test("includes suite version in parentheses")
        func includesSuiteVersion() {
            let id = ToolIdentity(tool: "reminders", built: "1.2.0", summary: "CLI for Apple Reminders")
            #expect(id.description == "reminders 1.2.0 (Get Clear \(suiteVersion)) — CLI for Apple Reminders")
        }
    }
}
