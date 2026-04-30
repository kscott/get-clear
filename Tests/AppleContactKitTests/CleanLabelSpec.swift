// CleanLabelSpec.swift
//
// Tests for ContactKit cleanLabel — strips Apple CNLabel format wrapping.

@testable import AppleContactKit
import Foundation
import Nimble
import Quick

final class CleanLabelSpec: QuickSpec {
    override class func spec() {
        describe("cleanLabel") {
            it("strips CNLabel prefix and suffix") {
                expect(cleanLabel("_$!<Work>!$_")) == "work"
            }
            it("lowercases plain label strings") {
                expect(cleanLabel("Mobile")) == "mobile"
            }
            it("passes through empty string unchanged") {
                expect(cleanLabel("")) == ""
            }
            it("lowercases without stripping when no prefix present") {
                expect(cleanLabel("iPhone")) == "iphone"
            }
            it("strips prefix only when suffix is absent") {
                expect(cleanLabel("_$!<Work")) == "work"
            }
            it("strips suffix only when prefix is absent") {
                expect(cleanLabel("Work>!$_")) == "work"
            }
        }
    }
}
