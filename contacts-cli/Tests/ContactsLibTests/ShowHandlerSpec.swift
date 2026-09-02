import ContactKit
import ContactsLib
import ContactTestSupport
import Testing

@Suite("handleShow")
struct ShowHandlerTests {
    let store = SpyContactStore()

    @Test("throws usage error when no name is given")
    func throwsWithoutName() async {
        await #expect(throws: (any Error).self) { try await handleShow(args: ["show"], store: store) }
    }

    @Test("returns card lines for a matched contact")
    func returnsCardLines() async throws {
        store.contacts = [aliceContact]
        let out = try await handleShow(args: ["show", "alice"], store: store)
        #expect(out.contains("Alice Smith"))
    }
}
