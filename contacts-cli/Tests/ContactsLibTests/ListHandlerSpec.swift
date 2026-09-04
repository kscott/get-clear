import ContactKit
import ContactsLib
import ContactTestSupport
import Testing

@Suite("handleLists")
struct HandleListsTests {
    let store = SpyContactStore()

    @Test("returns sorted group names one per line")
    func returnsSortedGroupNames() async throws {
        store.groups = [ContactGroup(identifier: "b", name: "Work"),
                        ContactGroup(identifier: "a", name: "Personal")]
        let out = try await handleLists(args: ["lists"], store: store)
        #expect(out == "Personal\nWork")
    }

    @Test("returns empty string when there are no groups")
    func emptyWhenNoGroups() async throws {
        store.groups = []
        let out = try await handleLists(args: ["lists"], store: store)
        #expect(out == "")
    }

    @Test("throws for a stray token after the command name")
    func throwsForStrayToken() async {
        await #expect(throws: (any Error).self) { try await handleLists(args: ["lists", "extra"], store: store) }
    }
}

@Suite("handleList")
struct HandleListTests {
    let store = SpyContactStore()

    @Test("throws usage error when no group name is given")
    func throwsWithoutGroupName() async {
        await #expect(throws: (any Error).self) { try await handleList(args: ["list"], store: store) }
    }

    @Test("returns contact rows sorted by name")
    func returnsContactRowsSorted() async throws {
        store.groups = [ContactGroup(identifier: "g1", name: "Friends")]
        store.contacts = [bobContact, aliceContact]
        let out = try await handleList(args: ["list", "Friends"], store: store)
        let lines = out.components(separatedBy: "\n")
        #expect(lines.first?.contains("Alice") == true)
        #expect(lines.last?.contains("Bob") == true)
    }
}
