import Quick
import Nimble
import ContactKit
import ContactTestSupport
import ContactsLib

final class ContactFormatterSpec: QuickSpec {
    override class func spec() {

        describe("cardLines") {
            context("name") {
                it("first line contains the contact name") {
                    let lines = cardLines(for: makeContact(name: "Alice Smith"))
                    expect(lines.first).to(contain("Alice Smith"))
                }
            }

            context("company") {
                it("includes company line when both name and company are present") {
                    let lines = cardLines(for: makeContact(name: "Alice", company: "Acme Corp"))
                    expect(lines.joined()).to(contain("Acme Corp"))
                }
                it("does not include a company line when company is empty") {
                    let lines = cardLines(for: makeContact(company: ""))
                    expect(lines.joined()).toNot(contain("Company"))
                }
                it("does not include a company line when name is empty") {
                    let lines = cardLines(for: makeContact(name: "", company: "Acme Corp"))
                    expect(lines.first(where: { $0.contains("Company") })).to(beNil())
                }
            }

            context("email") {
                it("includes email value in output") {
                    let c = makeContact(emails: [ContactField(label: "work", value: "alice@example.com")])
                    expect(cardLines(for: c).joined()).to(contain("alice@example.com"))
                }
                it("includes email label when label is non-empty") {
                    let c = makeContact(emails: [ContactField(label: "work", value: "alice@example.com")])
                    expect(cardLines(for: c).joined()).to(contain("work"))
                }
                it("omits label suffix when label is empty") {
                    let c = makeContact(emails: [ContactField(label: "", value: "alice@example.com")])
                    expect(cardLines(for: c).joined()).toNot(contain("()"))
                }
                it("includes a line per email for contacts with multiple emails") {
                    let c = makeContact(emails: [ContactField(label: "work", value: "alice@work.com"),
                                                 ContactField(label: "home", value: "alice@home.com")])
                    expect(cardLines(for: c).filter { $0.contains("Email") }.count) == 2
                }
            }

            context("phone") {
                it("includes phone value in output") {
                    let c = makeContact(phones: [ContactField(label: "mobile", value: "555-1234")])
                    expect(cardLines(for: c).joined()).to(contain("555-1234"))
                }
                it("omits label suffix when label is empty") {
                    let c = makeContact(phones: [ContactField(label: "", value: "555-1234")])
                    expect(cardLines(for: c).joined()).toNot(contain("()"))
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
