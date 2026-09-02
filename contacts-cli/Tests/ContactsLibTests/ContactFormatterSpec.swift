import ContactKit
import ContactsLib
import ContactTestSupport
import Testing

@Suite("cardLines")
struct ContactFormatterTests {
    @Suite("name")
    struct Name {
        @Test("first line contains the contact name")
        func firstLineContainsName() {
            let lines = cardLines(for: makeContact(name: "Alice Smith"))
            #expect(lines.first?.contains("Alice Smith") == true)
        }
    }

    @Suite("company")
    struct Company {
        @Test("includes company line when both name and company are present")
        func includesCompanyLine() {
            let lines = cardLines(for: makeContact(name: "Alice", company: "Acme Corp"))
            #expect(lines.joined().contains("Acme Corp"))
        }

        @Test("does not include a company line when company is empty")
        func noCompanyLineWhenEmpty() {
            let lines = cardLines(for: makeContact(company: ""))
            #expect(!lines.joined().contains("Company"))
        }

        @Test("does not include a company line when name is empty")
        func noCompanyLineWhenNameEmpty() {
            let lines = cardLines(for: makeContact(name: "", company: "Acme Corp"))
            #expect(lines.first(where: { $0.contains("Company") }) == nil)
        }
    }

    @Suite("email")
    struct Email {
        @Test("includes email value in output")
        func includesEmailValue() {
            let c = makeContact(emails: [ContactField(label: "work", value: "alice@example.com")])
            #expect(cardLines(for: c).joined().contains("alice@example.com"))
        }

        @Test("includes email label when label is non-empty")
        func includesEmailLabel() {
            let c = makeContact(emails: [ContactField(label: "work", value: "alice@example.com")])
            #expect(cardLines(for: c).joined().contains("work"))
        }

        @Test("omits label suffix when label is empty")
        func omitsLabelSuffixWhenEmpty() {
            let c = makeContact(emails: [ContactField(label: "", value: "alice@example.com")])
            #expect(!cardLines(for: c).joined().contains("()"))
        }

        @Test("includes a line per email for contacts with multiple emails")
        func linePerEmail() {
            let c = makeContact(emails: [ContactField(label: "work", value: "alice@work.com"),
                                         ContactField(label: "home", value: "alice@home.com")])
            #expect(cardLines(for: c).filter { $0.contains("Email") }.count == 2)
        }
    }

    @Suite("phone")
    struct Phone {
        @Test("includes phone value in output")
        func includesPhoneValue() {
            let c = makeContact(phones: [ContactField(label: "mobile", value: "555-1234")])
            #expect(cardLines(for: c).joined().contains("555-1234"))
        }

        @Test("omits label suffix when label is empty")
        func omitsLabelSuffixWhenEmpty() {
            let c = makeContact(phones: [ContactField(label: "", value: "555-1234")])
            #expect(!cardLines(for: c).joined().contains("()"))
        }
    }

    @Suite("org-only contact")
    struct OrgOnlyContact {
        @Test("first line contains the company name when name is empty")
        func firstLineContainsCompany() {
            let lines = cardLines(for: makeContact(name: "", company: "Acme Corp"))
            #expect(lines.first?.contains("Acme Corp") == true)
        }
    }
}
