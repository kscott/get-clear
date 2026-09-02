import ContactKit

/// @unchecked Sendable: `ContactStore` is `Sendable`, and this spy carries mutable
/// recording state. Safe because Swift Testing gives every `@Test` its own suite
/// instance (and thus its own spy) — no spy is ever shared across concurrent tests.
public final class SpyContactStore: ContactStore, @unchecked Sendable {
    public var contacts: [Contact] = []
    public var groups: [ContactGroup] = []
    public var addResult: Contact = makeContact()

    public var addedDrafts: [ContactDraft] = []
    public var addedToGroup: [(identifier: String, group: ContactGroup)] = []
    public var removedFromGroup: [(identifier: String, group: ContactGroup)] = []
    public var updatedItems: [(identifier: String, changes: ContactChanges)] = []
    public var renamedItems: [(identifier: String, to: String)] = []
    public var deletedIds: [String] = []

    public init() {}

    public func fetchGroups() async throws -> [ContactGroup] {
        groups
    }

    public func fetchContacts(in group: ContactGroup?) async throws -> [Contact] {
        contacts
    }

    public func add(_ draft: ContactDraft) async throws -> Contact {
        addedDrafts.append(draft)
        return addResult
    }

    public func add(identifier: String, to group: ContactGroup) async throws {
        addedToGroup.append((identifier, group))
    }

    public func remove(identifier: String, from group: ContactGroup) async throws {
        removedFromGroup.append((identifier, group))
    }

    public func update(identifier: String, changes: ContactChanges) async throws {
        updatedItems.append((identifier, changes))
    }

    public func rename(identifier: String, to newName: String) async throws {
        renamedItems.append((identifier, newName))
    }

    public func delete(identifier: String) async throws {
        deletedIds.append(identifier)
    }
}
