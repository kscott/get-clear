import Quick
import Nimble
import ContactKit
import ContactTestSupport
import ContactsLib

final class ChangeHandlerSpec: AsyncSpec {
    override class func spec() {

        var store: SpyContactStore!
        beforeEach { store = SpyContactStore() }

        describe("handleChange") {
            it("throws usage error when no name is given") {
                await expect { try await handleChange(args: ["change"], store: store) }
                    .to(throwError())
            }
            it("calls store.update with the resolved identifier and changes") {
                store.contacts = [aliceContact]
                _ = try await handleChange(args: ["change", "alice", "add", "email", "new@example.com"], store: store)
                expect(store.updatedItems.count) == 1
                expect(store.updatedItems.first?.identifier) == "alice-id"
                expect(store.updatedItems.first?.changes.email) == .added("new@example.com")
            }
            it("returns confirmation describing the change") {
                store.contacts = [aliceContact]
                let out = try await handleChange(args: ["change", "alice", "email", "none"], store: store)
                expect(out).to(contain("email cleared"))
            }
        }
    }
}
