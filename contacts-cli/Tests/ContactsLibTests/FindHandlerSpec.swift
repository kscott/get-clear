import ContactKit
import ContactsLib
import ContactTestSupport
import Testing

@Suite("handleFind")
struct FindHandlerTests {
    let store = SpyContactStore()

    @Test("throws usage error when no query is given")
    func throwsWithoutQuery() async {
        await #expect(throws: (any Error).self) { try await handleFind(args: ["find"], store: store) }
    }

    @Test("returns matching contacts")
    func returnsMatchingContacts() async throws {
        store.contacts = [aliceContact, bobContact]
        let out = try await handleFind(args: ["find", "alice"], store: store)
        #expect(out.contains("Alice Smith"))
    }

    @Test("returns not-found message for unmatched query")
    func returnsNotFoundMessage() async throws {
        store.contacts = []
        let out = try await handleFind(args: ["find", "xyzzy"], store: store)
        #expect(out.contains("No contacts matching"))
    }

    @Test("omits the email suffix for a contact with no email")
    func omitsEmailSuffixForNoEmail() async throws {
        store.contacts = [noEmailContact]
        let out = try await handleFind(args: ["find", "Dana"], store: store)
        #expect(!out.contains("<"))
    }
}
