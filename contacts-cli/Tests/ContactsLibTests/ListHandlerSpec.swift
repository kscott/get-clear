import Quick
import Nimble
import ContactKit
import ContactTestSupport
import ContactsLib

final class ListHandlerSpec: AsyncSpec {
    override class func spec() {

        var store: SpyContactStore!
        beforeEach { store = SpyContactStore() }

        describe("handleLists") {
            it("returns sorted group names one per line") {
                store.groups = [ContactGroup(identifier: "b", name: "Work"),
                                ContactGroup(identifier: "a", name: "Personal")]
                let out = try await handleLists(store: store)
                expect(out) == "Personal\nWork"
            }
            it("returns empty string when there are no groups") {
                store.groups = []
                let out = try await handleLists(store: store)
                expect(out) == ""
            }
        }

        describe("handleList") {
            it("throws usage error when no group name is given") {
                await expect { try await handleList(args: ["list"], store: store) }
                    .to(throwError())
            }
            it("returns contact rows sorted by name") {
                store.groups = [ContactGroup(identifier: "g1", name: "Friends")]
                store.contacts = [bobContact, aliceContact]
                let out = try await handleList(args: ["list", "Friends"], store: store)
                let lines = out.components(separatedBy: "\n")
                expect(lines.first).to(contain("Alice"))
                expect(lines.last).to(contain("Bob"))
            }
        }
    }
}
