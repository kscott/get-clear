// ReminderDispatchSpec.swift
//
// Tests for RemindersLib dispatchReminderRequest — how the helper side answers failures.
// Successful requests are covered end to end in RemoteReminderStoreSpec.

import Foundation
import GetClearKit
import RemindersLib
import Testing

private struct EventKitLikeError: LocalizedError {
    var errorDescription: String? {
        "List not found: Bills"
    }
}

/// A store whose every method throws the given error.
private struct FailingStore: ReminderStore {
    let error: Error
    func fetchLists() async throws -> [ReminderList] {
        throw error
    }

    func defaultList() async throws -> ReminderList {
        throw error
    }

    func fetchIncomplete(in _: ReminderList?) async throws -> [ReminderItem] {
        throw error
    }

    func fetchCompleted(in _: DateInterval) async throws -> [ReminderItem] {
        throw error
    }

    func add(_: ReminderItem) async throws -> ReminderItem {
        throw error
    }

    func update(identifier _: String, changes _: ReminderChanges) async throws {
        throw error
    }

    func complete(identifier _: String) async throws {
        throw error
    }

    func rename(identifier _: String, to _: String) async throws {
        throw error
    }

    func delete(identifier _: String) async throws {
        throw error
    }
}

private func reply(to request: ReminderHelperRequest, throwing error: Error) async throws -> HelperReply {
    try await dispatchReminderRequest(HelperCoding.encode(request), to: FailingStore(error: error))
}

@Suite("dispatchReminderRequest failures")
struct ReminderDispatchTests {
    @Test("a ReminderStoreError is answered as a typed tool error")
    func typedError() async throws {
        let expected = try HelperReply.failure(.toolError(HelperCoding.encode(ReminderStoreError.notFound("Pay rent"))))
        #expect(try await reply(to: .fetchLists, throwing: ReminderStoreError.notFound("Pay rent")) == expected)
    }

    @Test("any other error is answered with its exact description")
    func otherError() async throws {
        #expect(try await reply(to: .add(makeItem()), throwing: EventKitLikeError())
            == .failure(.storeError(message: "List not found: Bills")))
    }

    @Test("a request that isn't a reminders request is answered as a bad request")
    func badRequest() async {
        let answer = await dispatchReminderRequest(Data("{\"nope\":{}}".utf8), to: SpyStore())
        #expect(answer.isBadRequest)
    }
}

private extension HelperReply {
    var isBadRequest: Bool {
        if case .failure(.badRequest) = self { return true }
        return false
    }
}
