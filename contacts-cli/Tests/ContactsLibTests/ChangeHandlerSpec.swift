import ContactKit
import ContactsLib
import ContactTestSupport
import Testing

@Suite("handleChange")
struct ChangeHandlerTests {
    let store = SpyContactStore()

    @Test("throws usage error when no name is given")
    func throwsWithoutName() async {
        await #expect(throws: (any Error).self) { try await handleChange(args: ["change"], store: store) }
    }

    @Test("calls store.update with the resolved identifier and changes")
    func callsStoreUpdate() async throws {
        store.contacts = [aliceContact]
        _ = try await handleChange(args: ["change", "alice", "add", "email", "new@example.com"], store: store)
        #expect(store.updatedItems.count == 1)
        #expect(store.updatedItems.first?.identifier == "alice-id")
        #expect(store.updatedItems.first?.changes.email == .added("new@example.com"))
    }

    @Test("returns confirmation describing the change")
    func returnsConfirmation() async throws {
        store.contacts = [aliceContact]
        let out = try await handleChange(args: ["change", "alice", "email", "none"], store: store)
        #expect(out.contains("email cleared"))
    }

    // MARK: from/to pair verification

    @Test("produces removed for remove email")
    func producesRemovedForRemoveEmail() async throws {
        store.contacts = [aliceContact]
        _ = try await handleChange(args: ["change", "alice", "remove", "email", "alice@example.com"], store: store)
        #expect(store.updatedItems.first?.changes.email == .removed("alice@example.com"))
    }

    @Test("produces replaced with user-supplied from/to for email")
    func producesReplacedForEmail() async throws {
        store.contacts = [aliceContact]
        _ = try await handleChange(args: ["change", "alice", "email", "alice@example.com", "new@example.com"], store: store)
        #expect(store.updatedItems.first?.changes.email == .replaced(from: "alice@example.com", to: "new@example.com"))
    }

    @Test("produces cleared for email none")
    func producesClearedForEmailNone() async throws {
        store.contacts = [aliceContact]
        _ = try await handleChange(args: ["change", "alice", "email", "none"], store: store)
        #expect(store.updatedItems.first?.changes.email == .cleared)
    }

    @Test("produces replaced with empty from for company (no existing value in args)")
    func producesReplacedForCompany() async throws {
        store.contacts = [aliceContact]
        _ = try await handleChange(args: ["change", "alice", "company", "New Corp"], store: store)
        #expect(store.updatedItems.first?.changes.company == .replaced(from: "", to: "New Corp"))
    }

    @Test("produces cleared for company none")
    func producesClearedForCompanyNone() async throws {
        store.contacts = [aliceContact]
        _ = try await handleChange(args: ["change", "alice", "company", "none"], store: store)
        #expect(store.updatedItems.first?.changes.company == .cleared)
    }
}
