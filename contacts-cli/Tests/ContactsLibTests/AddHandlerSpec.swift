import Quick
import Nimble
import ContactKit
import ContactTestSupport
import ContactsLib

final class AddHandlerSpec: AsyncSpec {
    override class func spec() {

        var store: SpyContactStore!
        beforeEach { store = SpyContactStore() }

        describe("handleAdd (create)") {
            it("throws usage error when no name is given") {
                await expect { try await handleAdd(args: ["add"], store: store) }
                    .to(throwError())
            }
            it("calls store.add with the draft") {
                store.addResult = aliceContact
                _ = try await handleAdd(args: ["add", "Alice", "email", "alice@example.com"], store: store)
                expect(store.addedDrafts.count) == 1
                expect(store.addedDrafts.first?.name) == "Alice"
                expect(store.addedDrafts.first?.emails) == ["alice@example.com"]
            }
            it("returns confirmation containing the contact name") {
                store.addResult = aliceContact
                let out = try await handleAdd(args: ["add", "Alice"], store: store)
                expect(out).to(contain("Alice Smith"))
            }
        }

        describe("handleAdd (to group)") {
            it("calls store.add(identifier:to:) and returns confirmation") {
                store.contacts = [aliceContact]
                store.groups   = [ContactGroup(identifier: "g1", name: "Friends")]
                let out = try await handleAdd(args: ["add", "alice", "to", "Friends"], store: store)
                expect(store.addedToGroup.count) == 1
                expect(store.addedToGroup.first?.identifier) == "alice-id"
                expect(out).to(contain("Friends"))
            }
        }
    }
}
