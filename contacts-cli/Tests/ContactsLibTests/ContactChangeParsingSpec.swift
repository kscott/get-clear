import ContactKit
import ContactsLib
import GetClearKit
import Nimble
import Quick

final class ContactChangeParsingSpec: QuickSpec {
    override class func spec() {
        describe("parseContactChanges") {
            context("email: add") {
                it("returns added case for 'add email X'") {
                    let c = try! parseContactChanges(["add", "email", "alice@example.com"])
                    expect(c.email) == .added("alice@example.com")
                }
                it("leaves phone unchanged when only email is specified") {
                    let c = try! parseContactChanges(["add", "email", "alice@example.com"])
                    expect(c.phone) == .unchanged
                }
            }

            context("email: remove") {
                it("returns removed case for 'remove email X'") {
                    let c = try! parseContactChanges(["remove", "email", "alice@example.com"])
                    expect(c.email) == .removed("alice@example.com")
                }
            }

            context("email: replace") {
                it("returns replaced case for 'email OLD NEW'") {
                    let c = try! parseContactChanges(["email", "old@example.com", "new@example.com"])
                    expect(c.email) == .replaced(from: "old@example.com", to: "new@example.com")
                }
            }

            context("email: single token") {
                it("treats 'email X' at end of args as added") {
                    let c = try! parseContactChanges(["email", "alice@example.com"])
                    expect(c.email) == .added("alice@example.com")
                }
            }

            context("email: clear") {
                it("returns cleared for 'email none'") {
                    let c = try! parseContactChanges(["email", "none"])
                    expect(c.email) == .cleared
                }
            }

            context("phone: add") {
                it("returns added case for 'add phone P'") {
                    let c = try! parseContactChanges(["add", "phone", "555-1234"])
                    expect(c.phone) == .added("555-1234")
                }
                it("leaves email unchanged when only phone is specified") {
                    let c = try! parseContactChanges(["add", "phone", "555-1234"])
                    expect(c.email) == .unchanged
                }
            }

            context("phone: remove") {
                it("returns removed case for 'remove phone P'") {
                    let c = try! parseContactChanges(["remove", "phone", "555-1234"])
                    expect(c.phone) == .removed("555-1234")
                }
            }

            context("phone: replace") {
                it("returns replaced case for 'phone OLD NEW'") {
                    let c = try! parseContactChanges(["phone", "555-0000", "555-1111"])
                    expect(c.phone) == .replaced(from: "555-0000", to: "555-1111")
                }
            }

            context("phone: clear") {
                it("returns cleared for 'phone none'") {
                    let c = try! parseContactChanges(["phone", "none"])
                    expect(c.phone) == .cleared
                }
            }

            context("company") {
                it("returns replaced for 'company Acme Corp'") {
                    let c = try! parseContactChanges(["company", "Acme", "Corp"])
                    expect(c.company) == .replaced(from: "", to: "Acme Corp")
                }
                it("returns cleared for 'company none'") {
                    let c = try! parseContactChanges(["company", "none"])
                    expect(c.company) == .cleared
                }
            }

            context("combined") {
                it("handles email and phone in one call") {
                    let c = try! parseContactChanges(["email", "alice@example.com", "phone", "555-1234"])
                    expect(c.email) == .added("alice@example.com")
                    expect(c.phone) == .added("555-1234")
                }
            }

            context("empty input") {
                it("throws when no fields are specified") {
                    expect { try parseContactChanges([]) }.to(throwError())
                }
            }
        }
    }
}
