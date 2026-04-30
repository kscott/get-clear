import ContactKit
import ContactsLib
import ContactTestSupport
import Nimble
import Quick

final class FindHandlerSpec: AsyncSpec {
    override class func spec() {
        var store: SpyContactStore!
        beforeEach { store = SpyContactStore() }

        describe("handleFind") {
            it("throws usage error when no query is given") {
                await expect { try await handleFind(args: ["find"], store: store) }
                    .to(throwError())
            }
            it("returns matching contacts") {
                store.contacts = [aliceContact, bobContact]
                let out = try await handleFind(args: ["find", "alice"], store: store)
                expect(out).to(contain("Alice Smith"))
            }
            it("returns not-found message for unmatched query") {
                store.contacts = []
                let out = try await handleFind(args: ["find", "xyzzy"], store: store)
                expect(out).to(contain("No contacts matching"))
            }
        }
    }
}
