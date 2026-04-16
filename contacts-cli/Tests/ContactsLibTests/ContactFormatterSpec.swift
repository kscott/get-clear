// ContactFormatterSpec.swift
//
// Tests for ContactsLib ContactFormatter — cardLines display output.

import Quick
import Nimble
import Foundation
import ContactsLib

final class ContactFormatterSpec: QuickSpec {
    override class func spec() {

        func makeContact(
            name: String = "Alice Smith",
            emails: [(label: String, value: String)] = [],
            phones: [(label: String, value: String)] = [],
            company: String = ""
        ) -> ContactRecord {
            ContactRecord(name: name, emails: emails, phones: phones, company: company)
        }

        describe("cardLines") {

            context("name") {
                it("first line contains the contact name") {
                    let lines = cardLines(for: makeContact(name: "Alice Smith"))
                    expect(lines.first).to(contain("Alice Smith"))
                }
            }

            context("company") {
                it("includes company line when both name and company are present") {
                    let lines = cardLines(for: makeContact(company: "Acme Corp"))
                    expect(lines.joined()).to(contain("Acme Corp"))
                }
                it("does not include a company line when company is empty") {
                    let lines = cardLines(for: makeContact(company: ""))
                    expect(lines.joined()).toNot(contain("Company"))
                }
                it("does not include a company line when name is empty") {
                    let lines = cardLines(for: makeContact(name: "", company: "Acme Corp"))
                    let companyLine = lines.first(where: { $0.contains("Company") })
                    expect(companyLine).to(beNil())
                }
            }

            context("email") {
                it("includes email value in output") {
                    let lines = cardLines(for: makeContact(emails: [("work", "alice@example.com")]))
                    expect(lines.joined()).to(contain("alice@example.com"))
                }
                it("includes email label when label is non-empty") {
                    let lines = cardLines(for: makeContact(emails: [("work", "alice@example.com")]))
                    expect(lines.joined()).to(contain("work"))
                }
                it("omits label suffix when label is empty") {
                    let lines = cardLines(for: makeContact(emails: [("", "alice@example.com")]))
                    expect(lines.joined()).toNot(contain("()"))
                }
                it("includes a line per email for contacts with multiple emails") {
                    let emails: [(label: String, value: String)] = [
                        ("work", "alice@work.com"),
                        ("home", "alice@home.com"),
                    ]
                    let lines = cardLines(for: makeContact(emails: emails))
                    expect(lines.filter { $0.contains("Email") }.count) == 2
                }
            }

            context("phone") {
                it("includes phone value in output") {
                    let lines = cardLines(for: makeContact(phones: [("mobile", "555-1234")]))
                    expect(lines.joined()).to(contain("555-1234"))
                }
                it("includes phone label when label is non-empty") {
                    let lines = cardLines(for: makeContact(phones: [("mobile", "555-1234")]))
                    expect(lines.joined()).to(contain("mobile"))
                }
                it("omits label suffix when label is empty") {
                    let lines = cardLines(for: makeContact(phones: [("", "555-1234")]))
                    expect(lines.joined()).toNot(contain("()"))
                }
            }

            context("minimal contact") {
                it("returns at least one line for a name-only contact") {
                    let lines = cardLines(for: makeContact(name: "Bob", emails: [], phones: [], company: ""))
                    expect(lines.count) >= 1
                }
                it("does not include Email line for name-only contact") {
                    let lines = cardLines(for: makeContact(name: "Bob"))
                    expect(lines.joined()).toNot(contain("Email"))
                }
                it("does not include Phone line for name-only contact") {
                    let lines = cardLines(for: makeContact(name: "Bob"))
                    expect(lines.joined()).toNot(contain("Phone"))
                }
            }

            context("org-only contact") {
                it("first line contains the company name when name is empty") {
                    let lines = cardLines(for: makeContact(name: "", company: "Acme Corp"))
                    expect(lines.first).to(contain("Acme Corp"))
                }
            }
        }
    }
}
