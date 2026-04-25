// ContactSpec.swift
//
// Tests for GetClearKit Contact type — accessor convenience properties.

import Quick
import Nimble
import Foundation
import GetClearKit

final class ContactSpec: QuickSpec {
    override class func spec() {
        describe("Contact") {
            context("primaryEmail") {
                it("returns the value of the first email entry") {
                    let c = Contact(name: "Alice", emails: [ContactField(label: "work", value: "alice@example.com")], phones: [], company: "")
                    expect(c.primaryEmail) == "alice@example.com"
                }
                it("returns empty string when emails is empty") {
                    let c = Contact(name: "Alice", emails: [], phones: [], company: "")
                    expect(c.primaryEmail) == ""
                }
                it("returns the first email when multiple are present") {
                    let c = Contact(name: "Alice",
                                   emails: [ContactField(label: "work", value: "alice@work.com"),
                                            ContactField(label: "home", value: "alice@home.com")],
                                   phones: [], company: "")
                    expect(c.primaryEmail) == "alice@work.com"
                }
            }

            context("primaryPhone") {
                it("returns the value of the first phone entry") {
                    let c = Contact(name: "Alice", emails: [], phones: [ContactField(label: "mobile", value: "+15551234567")], company: "")
                    expect(c.primaryPhone) == "+15551234567"
                }
                it("returns empty string when phones is empty") {
                    let c = Contact(name: "Alice", emails: [], phones: [], company: "")
                    expect(c.primaryPhone) == ""
                }
            }
        }
    }
}
