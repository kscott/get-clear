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

    @Test("joins multiple unquoted tokens into the new name")
    func joinsUnquotedTokens() async throws {
        store.contacts = [aliceContact]
        _ = try await handleRename(args: ["rename", "alice", "Alice", "Jones"], store: store)
        #expect(store.renamedItems.first?.to == "Alice Jones")
    }
}
