// SetupHandlerSpec.swift
// Tests for MailLib selectIdentityEmail.

import Quick
import Nimble
import MailLib

final class MailSetupHandlerSpec: QuickSpec {
    override class func spec() {

        let identities = [
            MailIdentity(id: "id1", email: "a@example.com", name: "Alice"),
            MailIdentity(id: "id2", email: "b@example.com", name: "Bob"),
            MailIdentity(id: "id3", email: "c@example.com", name: "Charlie"),
        ]

        describe("selectIdentityEmail") {
            it("returns the first identity for choice 1") {
                expect(selectIdentityEmail(from: identities, choice: 1)) == "a@example.com"
            }
            it("returns the second identity for choice 2") {
                expect(selectIdentityEmail(from: identities, choice: 2)) == "b@example.com"
            }
            it("returns the last identity for choice at the boundary") {
                expect(selectIdentityEmail(from: identities, choice: 3)) == "c@example.com"
            }
            it("defaults to the first identity when choice is out of range high") {
                expect(selectIdentityEmail(from: identities, choice: 99)) == "a@example.com"
            }
            it("defaults to the first identity when choice is zero") {
                expect(selectIdentityEmail(from: identities, choice: 0)) == "a@example.com"
            }
            it("defaults to the first identity when choice is negative") {
                expect(selectIdentityEmail(from: identities, choice: -1)) == "a@example.com"
            }
            it("returns empty string for an empty identity list") {
                expect(selectIdentityEmail(from: [], choice: 1)) == ""
            }
        }
    }
}
