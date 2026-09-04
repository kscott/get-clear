import ContactKit
import ContactsLib
import ContactTestSupport
import Testing

@Suite("handleRename")
struct RenameHandlerTests {
    let store = SpyContactStore()

    @Test("throws usage error when fewer than two name args are given")
    func throwsWithFewerThanTwoNames() async {
        await #expect(throws: (any Error).self) { try await handleRename(args: ["rename", "Alice"], store: store) }
    }

    @Test("calls store.rename with the resolved identifier")
    func callsStoreRename() async throws {
        store.contacts = [aliceContact]
        _ = try await handleRename(args: ["rename", "alice", "Alice Jones"], store: store)
        #expect(store.renamedItems.first?.identifier == "alice-id")
        #expect(store.renamedItems.first?.to == "Alice Jones")
    }

    @Test("throws for an unquoted multi-word new name instead of joining it")
    func throwsForUnquotedNewName() async {
        store.contacts = [aliceContact]
        await #expect(throws: (any Error).self) {
            try await handleRename(args: ["rename", "alice", "Alice", "Jones"], store: store)
        }
    }
}
