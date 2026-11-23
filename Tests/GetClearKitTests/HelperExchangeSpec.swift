// HelperExchangeSpec.swift
//
// Tests for GetClearKit HelperExchange — HelperCaller and HelperResponder wired back to back,
// with a transport that calls the responder directly instead of crossing XPC.

import Foundation
import GetClearKit
import Testing

private enum EchoRequest: Codable, Equatable {
    case echo(String)
    case nothing
    case fail
    case failTyped
}

private enum ToolError: Error, Codable, Equatable {
    case notFound(String)
}

private struct PlainError: LocalizedError {
    var errorDescription: String? {
        "Calendar store unavailable."
    }
}

/// The helper side for EchoRequest: what a tool's dispatch function looks like.
private func respond(_ data: Data) async -> HelperReply {
    await HelperResponder.respond(
        to: data,
        as: EchoRequest.self,
        encodeToolError: { ($0 as? ToolError).flatMap { try? HelperCoding.encode($0) } },
        handle: { request in
            switch request {
            case let .echo(text): try HelperCoding.encode(text)
            case .nothing: try HelperCoding.encode(HelperNoResult())
            case .fail: throw PlainError()
            case .failTyped: throw ToolError.notFound("Pay rent")
            }
        }
    )
}

private let loopback = HelperCaller(
    tool: .reminders,
    appVersion: "1.4.0",
    transport: { await respond($0.request) },
    decodeToolError: { try? HelperCoding.decode(ToolError.self, from: $0) }
)

private func caller(replying reply: HelperReply) -> HelperCaller {
    HelperCaller(tool: .reminders, appVersion: "1.4.0", transport: { _ in reply })
}

@Suite("HelperCaller")
struct HelperCallerTests {
    @Suite("success")
    struct Success {
        @Test("returns the helper's result decoded as the requested type")
        func decodesResult() async throws {
            #expect(try await loopback.call(EchoRequest.echo("hi"), returning: String.self) == "hi")
        }

        @Test("perform completes without error for a method that returns nothing")
        func performCompletes() async {
            await #expect(throws: Never.self) {
                try await loopback.perform(EchoRequest.nothing)
            }
        }

        @Test("a result that doesn't decode as the requested type is an unreadable reply")
        func undecodableResult() async {
            await #expect(throws: HelperCallError.unreadableReply) {
                _ = try await caller(replying: .success(Data("{}".utf8))).call(EchoRequest.nothing, returning: [Int].self)
            }
        }
    }

    @Suite("envelope")
    struct Envelope {
        @Test("stamps the caller's tool and app version on every request")
        func stampsEnvelope() async throws {
            let seen = EnvelopeBox()
            let spy = HelperCaller(tool: .calendar, appVersion: "2.0.0", transport: { envelope in
                await seen.set(envelope)
                return try .success(HelperCoding.encode(HelperNoResult()))
            })
            try await spy.perform(EchoRequest.nothing)
            #expect(await seen.value.map { "\($0.tool) \($0.appVersion)" } == "calendar 2.0.0")
        }
    }

    @Suite("failures")
    struct Failures {
        @Test("a tool's own error comes back as the same typed value")
        func typedErrorRethrown() async {
            await #expect(throws: ToolError.notFound("Pay rent")) {
                try await loopback.perform(EchoRequest.failTyped)
            }
        }

        @Test("any other store error comes back with its exact description")
        func storeErrorKeepsText() async {
            let error = await #expect(throws: HelperStoreError.self) {
                try await loopback.perform(EchoRequest.fail)
            }
            #expect(error?.localizedDescription == "Calendar store unavailable.")
        }

        @Test("a denied permission throws the permission's message")
        func accessDenied() async {
            let error = await #expect(throws: HelperCallError.self) {
                try await caller(replying: .failure(.accessDenied(.reminders))).perform(EchoRequest.nothing)
            }
            #expect(error?.localizedDescription == StoreKind.reminders.deniedMessage)
        }

        @Test("a version mismatch that reaches the caller names the helper's version")
        func versionMismatch() async {
            await #expect(throws: HelperCallError.versionMismatch(helperApp: "1.3.9")) {
                try await caller(replying: .failure(.versionMismatch(helperProtocol: 1, helperApp: "1.3.9"))).perform(EchoRequest.nothing)
            }
        }

        @Test("a tool-error payload the tool can't decode is an unreadable reply")
        func undecodableToolError() async {
            await #expect(throws: HelperCallError.unreadableReply) {
                try await caller(replying: .failure(.toolError(Data("garbage".utf8)))).perform(EchoRequest.nothing)
            }
        }

        @Test("a request the helper couldn't read surfaces as a bad request")
        func badRequest() async {
            await #expect(throws: HelperCallError.badRequest("nope")) {
                try await caller(replying: .failure(.badRequest("nope"))).perform(EchoRequest.nothing)
            }
        }
    }
}

@Suite("HelperResponder")
struct HelperResponderTests {
    @Test("a request that doesn't decode is answered with a bad-request failure")
    func undecodableRequest() async {
        #expect(await respond(Data("not json".utf8)).isBadRequest)
    }
}

private extension HelperReply {
    var isBadRequest: Bool {
        if case .failure(.badRequest) = self { return true }
        return false
    }
}

private actor EnvelopeBox {
    var value: HelperEnvelope?
    func set(_ envelope: HelperEnvelope) {
        value = envelope
    }
}
