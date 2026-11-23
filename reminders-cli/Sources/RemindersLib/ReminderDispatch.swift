// ReminderDispatch.swift
//
// The helper side of RemoteReminderStore: decodes one ReminderHelperRequest, runs it against
// the real store, and answers with the encoded result or error (spec 018). Pure over the
// ReminderStore protocol, so tests run it against a spy.

import Foundation
import GetClearKit

public func dispatchReminderRequest(_ request: Data, to store: any ReminderStore) async -> HelperReply {
    await HelperResponder.respond(
        to: request,
        as: ReminderHelperRequest.self,
        encodeToolError: { ($0 as? ReminderStoreError).flatMap { try? HelperCoding.encode($0) } },
        handle: { try await run($0, on: store) }
    )
}

private func run(_ request: ReminderHelperRequest, on store: any ReminderStore) async throws -> Data {
    switch request {
    case .fetchLists:
        return try await HelperCoding.encode(store.fetchLists())
    case .defaultList:
        return try await HelperCoding.encode(store.defaultList())
    case let .fetchIncomplete(list):
        return try await HelperCoding.encode(store.fetchIncomplete(in: list))
    case let .fetchCompleted(range):
        return try await HelperCoding.encode(store.fetchCompleted(in: range))
    case let .add(item):
        return try await HelperCoding.encode(store.add(item))
    case let .update(identifier, changes):
        try await store.update(identifier: identifier, changes: changes)
    case let .complete(identifier):
        try await store.complete(identifier: identifier)
    case let .rename(identifier, title):
        try await store.rename(identifier: identifier, to: title)
    case let .delete(identifier):
        try await store.delete(identifier: identifier)
    }
    return try HelperCoding.encode(HelperNoResult())
}
