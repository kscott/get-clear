// HelperGateSpec.swift
//
// Tests for GetClearKit HelperGate — version check, permission check, then routing.

import Foundation
import GetClearKit
import Testing

/// Records which permissions were checked and whether routing happened.
private actor Log {
    var checked: [StoreKind] = []
    var routed = 0
    func check(_ kind: StoreKind) {
        checked.append(kind)
    }

    func route() {
        routed += 1
    }
}

private let routedReply = HelperReply.success(Data("\"ok\"".utf8))

private func gate(granted: Set<StoreKind>, needs: [StoreKind], log: Log) -> HelperGate {
    HelperGate(
        appVersion: "1.4.0",
        requiredAccess: { _ in needs },
        hasAccess: { kind in
            await log.check(kind)
            return granted.contains(kind)
        },
        route: { _ in
            await log.route()
            return routedReply
        }
    )
}

private func envelope(appVersion: String = "1.4.0") -> HelperEnvelope {
    HelperEnvelope(appVersion: appVersion, tool: .text, request: Data("{}".utf8))
}

@Suite("HelperGate")
struct HelperGateTests {
    @Suite("version")
    struct Version {
        @Test("an envelope from a different build is turned away with the helper's version")
        func mismatchReply() async {
            let reply = await gate(granted: [], needs: [], log: Log()).reply(to: envelope(appVersion: "1.3.9"))
            #expect(reply == .failure(.versionMismatch(helperProtocol: HelperEnvelope.currentProtocolVersion, helperApp: "1.4.0")))
        }

        @Test("a mismatched envelope never asks for a permission")
        func mismatchSkipsAccess() async {
            let log = Log()
            _ = await gate(granted: [], needs: [.reminders], log: log).reply(to: envelope(appVersion: "1.3.9"))
            #expect(await log.checked.isEmpty)
        }
    }

    @Suite("access")
    struct Access {
        @Test("a granted request is routed and its reply returned")
        func grantedRoutes() async {
            let reply = await gate(granted: [.messages], needs: [.messages], log: Log()).reply(to: envelope())
            #expect(reply == routedReply)
        }

        @Test("a denied permission is reported by name")
        func deniedReported() async {
            let reply = await gate(granted: [.messages], needs: [.contacts, .messages], log: Log()).reply(to: envelope())
            #expect(reply == .failure(.accessDenied(.contacts)))
        }

        @Test("a denied request never reaches the store")
        func deniedNotRouted() async {
            let log = Log()
            _ = await gate(granted: [], needs: [.reminders], log: log).reply(to: envelope())
            #expect(await log.routed == 0)
        }

        @Test("checking stops at the first denied permission, so later prompts don't appear")
        func stopsAtFirstDenial() async {
            let log = Log()
            _ = await gate(granted: [], needs: [.contacts, .messages], log: log).reply(to: envelope())
            #expect(await log.checked == [.contacts])
        }

        @Test("a request that needs no permission is routed without any check")
        func noneNeeded() async {
            let log = Log()
            _ = await gate(granted: [], needs: [], log: log).reply(to: envelope())
            #expect(await log.checked.isEmpty)
        }
    }

    @Suite("raw bytes")
    struct RawBytes {
        @Test("bytes that aren't an envelope are answered as a bad request")
        func notAnEnvelope() async {
            let reply = await gate(granted: [], needs: [], log: Log()).reply(to: Data("hello".utf8))
            #expect(reply == .failure(.badRequest("not a Get Clear helper envelope")))
        }

        @Test("an encoded envelope is decoded and gated like any other")
        func encodedEnvelope() async throws {
            let reply = try await gate(granted: [], needs: [], log: Log()).reply(to: HelperCoding.encode(envelope()))
            #expect(reply == routedReply)
        }
    }
}
