import Quick
import Nimble
import ContactKit
import ContactTestSupport
import ContactsLib

final class RemoveHandlerSpec: AsyncSpec {
    override class func spec() {

        var store: SpyContactStore!
        beforeEach { store = SpyContactStore() }

        describe("handleRemove (delete)") {
            it("throws usage error when no name is given") {
                await expect { try await handleRemove(args: ["remove"], store: store) }
                    .to(throwError())
            }
            it("calls store.delete with the resolved identifier") {
                store.contacts = [aliceContact]
                _ = try await handleRemove(args: ["remove", "alice"], store: store)
                expect(store.deletedIds) == ["alice-id"]
            }
        }

        describe("handleRemove (from group)") {
            it("calls store.remove(identifier:from:) and returns confirmation") {
                store.contacts = [aliceContact]
                store.groups   = [ContactGroup(identifier: "g1", name: "Friends")]
                let out = try await handleRemove(args: ["remove", "alice", "from", "Friends"], store: store)
                expect(store.removedFromGroup.count) == 1
                expect(store.removedFromGroup.first?.identifier) == "alice-id"
                expect(out).to(contain("Friends"))
            }
        }
    }
}
