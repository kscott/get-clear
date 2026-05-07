// ContactLabelSpec.swift

import ContactKit
import Nimble
import Quick

final class ContactLabelSpec: QuickSpec {
    override class func spec() {
        describe("cleanLabel") {
            it("strips Apple CNLabel delimiters from a wrapped label") {
                expect(cleanLabel("_$!<Home>!$_")) == "home"
            }
            it("strips delimiters from a phone label") {
                expect(cleanLabel("_$!<Mobile>!$_")) == "mobile"
            }
            it("lowercases a plain label with no delimiters") {
                expect(cleanLabel("Work")) == "work"
            }
            it("returns an already-clean label unchanged except lowercased") {
                expect(cleanLabel("home")) == "home"
            }
            it("returns an empty string unchanged") {
                expect(cleanLabel("")) == ""
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
