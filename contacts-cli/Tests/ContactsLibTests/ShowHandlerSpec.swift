import ContactKit
import ContactsLib
import ContactTestSupport
import Nimble
import Quick

final class ShowHandlerSpec: AsyncSpec {
    override class func spec() {
        var store: SpyContactStore!
        beforeEach { store = SpyContactStore() }

        describe("handleShow") {
            it("throws usage error when no name is given") {
                await expect { try await handleShow(args: ["show"], store: store) }
                    .to(throwError())
            }
            it("returns card lines for a matched contact") {
                store.contacts = [aliceContact]
                let out = try await handleShow(args: ["show", "alice"], store: store)
                expect(out).to(contain("Alice Smith"))
            }
        }
    }
}
