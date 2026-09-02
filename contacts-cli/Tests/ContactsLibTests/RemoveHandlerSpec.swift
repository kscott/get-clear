import ContactKit
import ContactsLib
import ContactTestSupport
import Testing

@Suite("handleRemove (delete)")
struct HandleRemoveDeleteTests {
    let store = SpyContactStore()

    @Test("throws usage error when no name is given")
    func throwsWithoutName() async {
        await #expect(throws: (any Error).self) { try await handleRemove(args: ["remove"], store: store) }
    }

    @Test("calls store.delete with the resolved identifier")
    func callsStoreDelete() async throws {
        store.contacts = [aliceContact]
        _ = try await handleRemove(args: ["remove", "alice"], store: store)
        #expect(store.deletedIds == ["alice-id"])
    }
}

@Suite("handleRemove (from group)")
struct HandleRemoveFromGroupTests {
    let store = SpyContactStore()

    @Test("calls store.remove(identifier:from:) and returns confirmation")
    func callsRemoveFromGroup() async throws {
        store.contacts = [aliceContact]
        store.groups = [ContactGroup(identifier: "g1", name: "Friends")]
        let out = try await handleRemove(args: ["remove", "alice", "from", "Friends"], store: store)
        #expect(store.removedFromGroup.count == 1)
        #expect(store.removedFromGroup.first?.identifier == "alice-id")
        #expect(out.contains("Friends"))
    }
}
