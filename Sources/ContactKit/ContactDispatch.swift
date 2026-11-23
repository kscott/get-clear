// ContactDispatch.swift
//
// The helper side of RemoteContactStore: decodes one ContactHelperRequest, runs it against
// the real store, and answers with the encoded result or error (spec 018). Pure over the
// ContactStore protocol, so tests run it against a spy.

import Foundation
import GetClearKit

public func dispatchContactRequest(_ request: Data, to store: any ContactStore) async -> HelperReply {
    await HelperResponder.respond(
        to: request,
        as: ContactHelperRequest.self,
        encodeToolError: { ($0 as? ContactStoreError).flatMap { try? HelperCoding.encode($0) } },
        handle: { try await run($0, on: store) }
    )
}

private func run(_ request: ContactHelperRequest, on store: any ContactStore) async throws -> Data {
    switch request {
    case .fetchGroups:
        return try await HelperCoding.encode(store.fetchGroups())
    case let .fetchContacts(group):
        return try await HelperCoding.encode(store.fetchContacts(in: group))
    case let .add(draft):
        return try await HelperCoding.encode(store.add(draft))
    case let .addToGroup(identifier, group):
        try await store.add(identifier: identifier, to: group)
    case let .removeFromGroup(identifier, group):
        try await store.remove(identifier: identifier, from: group)
    case let .update(identifier, changes):
        try await store.update(identifier: identifier, changes: changes)
    case let .rename(identifier, newName):
        try await store.rename(identifier: identifier, to: newName)
    case let .delete(identifier):
        try await store.delete(identifier: identifier)
    }
    return try HelperCoding.encode(HelperNoResult())
}
