import ContactKit
import ContactsLib
import ContactTestSupport
import Nimble
import Quick

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

            // MARK: from/to pair verification

            it("produces removed for remove email") {
                store.contacts = [aliceContact]
                _ = try await handleChange(args: ["change", "alice", "remove", "email", "alice@example.com"], store: store)
                expect(store.updatedItems.first?.changes.email) == .removed("alice@example.com")
            }
            it("produces replaced with user-supplied from/to for email") {
                store.contacts = [aliceContact]
                _ = try await handleChange(args: ["change", "alice", "email", "alice@example.com", "new@example.com"], store: store)
                expect(store.updatedItems.first?.changes.email) == .replaced(from: "alice@example.com", to: "new@example.com")
            }
            it("produces cleared for email none") {
                store.contacts = [aliceContact]
                _ = try await handleChange(args: ["change", "alice", "email", "none"], store: store)
                expect(store.updatedItems.first?.changes.email) == .cleared
            }
            it("produces replaced with empty from for company (no existing value in args)") {
                store.contacts = [aliceContact]
                _ = try await handleChange(args: ["change", "alice", "company", "New Corp"], store: store)
                expect(store.updatedItems.first?.changes.company) == .replaced(from: "", to: "New Corp")
            }
            it("produces cleared for company none") {
                store.contacts = [aliceContact]
                _ = try await handleChange(args: ["change", "alice", "company", "none"], store: store)
                expect(store.updatedItems.first?.changes.company) == .cleared
            }
        }
    }
}
