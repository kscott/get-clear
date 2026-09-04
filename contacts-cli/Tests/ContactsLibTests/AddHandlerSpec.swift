import ContactKit
import ContactsLib
import ContactTestSupport
import Testing

@Suite("handleAdd (create)")
struct HandleAddCreateTests {
    let store = SpyContactStore()

    @Test("throws usage error when no name is given")
    func throwsWithoutName() async {
        await #expect(throws: (any Error).self) { try await handleAdd(args: ["add"], store: store) }
    }

    @Test("calls store.add with the draft")
    func callsStoreAddWithDraft() async throws {
        store.addResult = aliceContact
        _ = try await handleAdd(args: ["add", "Alice", "email", "alice@example.com"], store: store)
        #expect(store.addedDrafts.count == 1)
        #expect(store.addedDrafts.first?.name == "Alice")
        #expect(store.addedDrafts.first?.emails == ["alice@example.com"])
    }

    @Test("returns confirmation containing the contact name")
    func returnsConfirmationWithName() async throws {
        store.addResult = aliceContact
        let out = try await handleAdd(args: ["add", "Alice"], store: store)
        #expect(out.contains("Alice Smith"))
    }

    @Test("throws when the same keyword is given twice")
    func throwsForDuplicateKeyword() async {
        await #expect(throws: (any Error).self) {
            try await handleAdd(args: ["add", "Alice", "email", "a@x.com", "email", "b@x.com"], store: store)
        }
    }

    @Test("throws naming an unrecognized keyword")
    func throwsForUnrecognizedKeyword() async {
        await #expect(throws: (any Error).self) {
            try await handleAdd(args: ["add", "Alice", "birthday", "march 1"], store: store)
        }
    }
}

@Suite("handleAdd (to group)")
struct HandleAddToGroupTests {
    let store = SpyContactStore()

    @Test("calls store.add(identifier:to:) and returns confirmation")
    func callsAddToGroup() async throws {
        store.contacts = [aliceContact]
        store.groups = [ContactGroup(identifier: "g1", name: "Friends")]
        let out = try await handleAdd(args: ["add", "alice", "to", "Friends"], store: store)
        #expect(store.addedToGroup.count == 1)
        #expect(store.addedToGroup.first?.identifier == "alice-id")
        #expect(out.contains("Friends"))
    }

    @Test("throws when 'to' is combined with email")
    func throwsWhenCombinedWithFields() async {
        store.contacts = [aliceContact]
        store.groups = [ContactGroup(identifier: "g1", name: "Friends")]
        await #expect(throws: (any Error).self) {
            try await handleAdd(args: ["add", "alice", "to", "Friends", "email", "alice@example.com"], store: store)
        }
    }
}
