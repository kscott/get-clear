import ContactKit
import ContactsLib
import ContactTestSupport
import Nimble
import Quick

final class RenameHandlerSpec: AsyncSpec {
    override class func spec() {
        var store: SpyContactStore!
        beforeEach { store = SpyContactStore() }

        describe("handleRename") {
            it("throws usage error when fewer than two name args are given") {
                await expect { try await handleRename(args: ["rename", "Alice"], store: store) }
                    .to(throwError())
            }
            it("calls store.rename with the resolved identifier") {
                store.contacts = [aliceContact]
                _ = try await handleRename(args: ["rename", "alice", "Alice Jones"], store: store)
                expect(store.renamedItems.first?.identifier) == "alice-id"
                expect(store.renamedItems.first?.to) == "Alice Jones"
            }
            it("joins multiple unquoted tokens into the new name") {
                store.contacts = [aliceContact]
                _ = try await handleRename(args: ["rename", "alice", "Alice", "Jones"], store: store)
                expect(store.renamedItems.first?.to) == "Alice Jones"
            }
        }
    }
}
