// ContactHelperRequest.swift
//
// One case per ContactStore method: what a command asks the Get Clear helper to do with
// Contacts (spec 018). Adding a store method means adding a case here, in
// RemoteContactStore, and in ContactDispatch.

public enum ContactHelperRequest: Codable, Equatable, Sendable {
    case fetchGroups
    case fetchContacts(group: ContactGroup?)
    case add(ContactDraft)
    case addToGroup(identifier: String, group: ContactGroup)
    case removeFromGroup(identifier: String, group: ContactGroup)
    case update(identifier: String, changes: ContactChanges)
    case rename(identifier: String, newName: String)
    case delete(identifier: String)
}
