// ChangeCommandSpec.swift
//
// Tests for ContactsLib ChangeCommand — parseContactChanges input parsing.

import Quick
import Nimble
import Foundation
import ContactsLib

final class ChangeCommandSpec: QuickSpec {
    override class func spec() {

        // MARK: - email variants

        describe("parseContactChanges") {

            context("add email") {
                it("returns added case for 'add email X'") {
                    let c = try! parseContactChanges("add email alice@example.com")
                    if case .added(let v) = c.email { expect(v) == "alice@example.com" }
                    else { fail("expected .added") }
                }
                it("includes a description for the added email") {
                    let c = try! parseContactChanges("add email alice@example.com")
                    expect(c.descriptions).to(contain("email +alice@example.com"))
                }
                it("leaves phone unchanged when only email is specified") {
                    let c = try! parseContactChanges("add email alice@example.com")
                    if case .unchanged = c.phone { /* pass */ }
                    else { fail("expected .unchanged") }
                }
            }

            context("remove email") {
                it("returns removed case for 'remove email X'") {
                    let c = try! parseContactChanges("remove email alice@example.com")
                    if case .removed(let v) = c.email { expect(v) == "alice@example.com" }
                    else { fail("expected .removed") }
                }
                it("includes a description for the removed email") {
                    let c = try! parseContactChanges("remove email alice@example.com")
                    expect(c.descriptions).to(contain("email -alice@example.com"))
                }
            }

            context("replace email") {
                it("returns replaced case for 'email X'") {
                    let c = try! parseContactChanges("email bob@example.com")
                    if case .replaced(let v) = c.email { expect(v) == "bob@example.com" }
                    else { fail("expected .replaced") }
                }
                it("includes a description for the replaced email") {
                    let c = try! parseContactChanges("email bob@example.com")
                    expect(c.descriptions).to(contain("email → bob@example.com"))
                }
            }

            context("clear email") {
                it("returns cleared case for 'email none'") {
                    let c = try! parseContactChanges("email none")
                    if case .cleared = c.email { /* pass */ }
                    else { fail("expected .cleared") }
                }
                it("includes a description for the cleared email") {
                    let c = try! parseContactChanges("email none")
                    expect(c.descriptions).to(contain("email cleared"))
                }
            }

            // MARK: - phone variants

            context("add phone") {
                it("returns added case for 'add phone P'") {
                    let c = try! parseContactChanges("add phone 555-1234")
                    if case .added(let v) = c.phone { expect(v) == "555-1234" }
                    else { fail("expected .added") }
                }
                it("includes a description for the added phone") {
                    let c = try! parseContactChanges("add phone 555-1234")
                    expect(c.descriptions).to(contain("phone +555-1234"))
                }
                it("leaves email unchanged when only phone is specified") {
                    let c = try! parseContactChanges("add phone 555-1234")
                    if case .unchanged = c.email { /* pass */ }
                    else { fail("expected .unchanged") }
                }
            }

            context("remove phone") {
                it("returns removed case for 'remove phone P'") {
                    let c = try! parseContactChanges("remove phone 555-1234")
                    if case .removed(let v) = c.phone { expect(v) == "555-1234" }
                    else { fail("expected .removed") }
                }
                it("includes a description for the removed phone") {
                    let c = try! parseContactChanges("remove phone 555-1234")
                    expect(c.descriptions).to(contain("phone -555-1234"))
                }
            }

            context("replace phone") {
                it("returns replaced case for 'phone P'") {
                    let c = try! parseContactChanges("phone 555-5678")
                    if case .replaced(let v) = c.phone { expect(v) == "555-5678" }
                    else { fail("expected .replaced") }
                }
                it("includes a description for the replaced phone") {
                    let c = try! parseContactChanges("phone 555-5678")
                    expect(c.descriptions).to(contain("phone → 555-5678"))
                }
            }

            context("clear phone") {
                it("returns cleared case for 'phone none'") {
                    let c = try! parseContactChanges("phone none")
                    if case .cleared = c.phone { /* pass */ }
                    else { fail("expected .cleared") }
                }
                it("includes a description for the cleared phone") {
                    let c = try! parseContactChanges("phone none")
                    expect(c.descriptions).to(contain("phone cleared"))
                }
            }

            // MARK: - combined and error cases

            context("both fields in one call") {
                it("returns non-unchanged for both email and phone") {
                    let c = try! parseContactChanges("email alice@example.com phone 555-1234")
                    if case .unchanged = c.email { fail("expected email to be set") }
                    if case .unchanged = c.phone { fail("expected phone to be set") }
                }
                it("includes descriptions for both fields") {
                    let c = try! parseContactChanges("email alice@example.com phone 555-1234")
                    expect(c.descriptions.count) == 2
                }
            }

            context("empty input") {
                it("throws when no fields are specified") {
                    expect { try parseContactChanges("") }.to(throwError())
                }
            }
        }
    }
}
