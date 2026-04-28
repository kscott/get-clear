import Quick
import Nimble
import Foundation
import ContactKit
import ContactTestSupport
import ContactsLib

// MARK: - Spec

final class ContactHandlerSpec: AsyncSpec {
    override class func spec() {

        var store: SpyContactStore!
        beforeEach { store = SpyContactStore() }

        // MARK: handleOpen

        describe("handleOpen") {
            it("calls the opener with the Contacts app URL") {
                var opened: URL?
                _ = handleOpen(opener: { opened = $0 })
                expect(opened?.path).to(contain("Contacts.app"))
            }
        }

        // MARK: handleLists

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

        // MARK: handleList

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

        // MARK: handleExport

        describe("handleExport") {
            it("throws usage error when no group name is given") {
                await expect { try await handleExport(args: ["export"], store: store) }
                    .to(throwError())
            }
            it("returns paste-ready address string for the group") {
                store.groups = [ContactGroup(identifier: "g1", name: "Work")]
                store.contacts = [aliceContact]
                let out = try await handleExport(args: ["export", "Work"], store: store)
                expect(out).to(contain("alice@example.com"))
            }
        }

        // MARK: handleFind

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

        // MARK: handleShow

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

        // MARK: handleAdd — create contact

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

        // MARK: handleAdd — add to group

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

        // MARK: handleChange

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

        // MARK: handleRename

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
        }

        // MARK: handleRemove — delete contact

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

        // MARK: handleRemove — remove from group

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
