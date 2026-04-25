// UsageTextSpec.swift
// Tests for TextLib usageText.

import Quick
import Nimble
import TextLib

final class UsageTextSpec: QuickSpec {
    override class func spec() {
        describe("usageText") {
            it("contains the send command") {
                expect(usageText()).to(contain("text send <contact> <message...>"))
            }
            it("contains the open command") {
                expect(usageText()).to(contain("text open"))
            }
            it("contains the feedback URL") {
                expect(usageText()).to(contain("github.com/kscott/get-clear/issues"))
            }
        }
    }
}
