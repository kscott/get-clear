import ContactsLib
import Testing

@Suite("usageText")
struct UsageTextTests {
    @Test("contains the list command")
    func containsListCommand() {
        #expect(usageText(identity: "contacts").contains("contacts list"))
    }

    @Test("contains the find command")
    func containsFindCommand() {
        #expect(usageText(identity: "contacts").contains("contacts find"))
    }

    @Test("contains the add command")
    func containsAddCommand() {
        #expect(usageText(identity: "contacts").contains("contacts add"))
    }

    @Test("contains the feedback URL")
    func containsFeedbackURL() {
        #expect(usageText(identity: "contacts").contains("github.com/kscott/get-clear/issues"))
    }

    @Test("does not contain the removed export command")
    func noExportCommand() {
        #expect(!usageText(identity: "contacts").contains("export"))
    }
}
