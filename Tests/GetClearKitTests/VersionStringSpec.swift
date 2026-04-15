// VersionStringSpec.swift
// Tests for versionString().

import Quick
import Nimble
import GetClearKit

final class VersionStringSpec: QuickSpec {
    override class func spec() {
        describe("versionString") {
            context("when built version matches suite version") {
                it("returns the tool name and version only") {
                    expect(versionString(tool: "get-clear", built: "1.3.0", suite: "1.3.0")) == "get-clear 1.3.0"
                }
            }
            context("when built version differs from suite version") {
                it("appends the suite version in parentheses") {
                    expect(versionString(tool: "reminders", built: "1.2.0", suite: "1.3.0")) == "reminders 1.2.0 (Get Clear 1.3.0)"
                }
            }
        }
    }
}
