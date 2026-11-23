// ContactDispatchSpec.swift
//
// Tests for ContactKit dispatchContactRequest — how the helper side answers failures.
// Successful requests are covered end to end in RemoteContactStoreSpec.

import ContactKit
import ContactTestSupport
import Foundation
import GetClearKit
import Testing

private struct ContactsLikeError: LocalizedError {
    var errorDescription: String? {
        "Contact not found: c-1"
    }
}

/// A store whose every method throws the given error.
private struct FailingStore: ContactStore {
    let error: ContactsLikeError?
    let typed: ContactStoreError?

    private func fail() throws -> Never {
        if let typed { throw typed }
        throw error ?? ContactsLikeError()
    }

    func fetchGroups() async throws -> [ContactGroup] {
        try fail()
    }

    func fetchContacts(in _: ContactGroup?) async throws -> [Contact] {
        try fail()
    }

    func add(_: ContactDraft) async throws -> Contact {
        try fail()
    }

    func add(identifier _: String, to _: ContactGroup) async throws {
        try fail()
    }

    func remove(identifier _: String, from _: ContactGroup) async throws {
        try fail()
    }

    func update(identifier _: String, changes _: ContactChanges) async throws {
        try fail()
    }

    func rename(identifier _: String, to _: String) async throws {
        try fail()
    }

    func delete(identifier _: String) async throws {
        try fail()
    }
}

@Suite("dispatchContactRequest failures")
struct ContactDispatchTests {
    @Test("a ContactStoreError is answered as a typed tool error")
    func typedError() async throws {
        let store = FailingStore(error: nil, typed: .groupNotFound("Team"))
        let expected = try HelperReply.failure(.toolError(HelperCoding.encode(ContactStoreError.groupNotFound("Team"))))
        #expect(try await dispatchContactRequest(HelperCoding.encode(ContactHelperRequest.fetchGroups), to: store) == expected)
    }

    @Test("any other error is answered with its exact description")
    func otherError() async throws {
        let store = FailingStore(error: ContactsLikeError(), typed: nil)
        let request = try HelperCoding.encode(ContactHelperRequest.delete(identifier: "c-1"))
        #expect(await dispatchContactRequest(request, to: store) == .failure(.storeError(message: "Contact not found: c-1")))
    }

    @Test("a request that isn't a contacts request is answered as a bad request")
    func badRequest() async {
        let answer = await dispatchContactRequest(Data("{\"nope\":{}}".utf8), to: SpyContactStore())
        #expect(answer.isBadRequest)
    }
}

private extension HelperReply {
    var isBadRequest: Bool {
        if case .failure(.badRequest) = self { return true }
        return false
    }
}
