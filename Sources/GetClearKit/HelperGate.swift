// HelperGate.swift
//
// The helper's decision for each incoming envelope, in contract order: reject a sender from a
// different build (C2), make sure every permission the request needs is granted, prompting on
// first use (C3), then route it to the tool's dispatch. Pure: permission checks and routing are
// injected, so the XPC service is only transport glue.
//
// See specs/018-app-bundle-identity/contracts/helper-protocol.md.

import Foundation

public struct HelperGate: Sendable {
    public let protocolVersion: Int
    public let appVersion: String
    /// The permissions a request needs, e.g. Contacts for a text addressed by name.
    public let requiredAccess: @Sendable (HelperEnvelope) -> [StoreKind]
    /// Whether Get Clear holds a permission; asks the user the first time.
    public let hasAccess: @Sendable (StoreKind) async -> Bool
    /// Runs a request that has passed the gate.
    public let route: @Sendable (HelperEnvelope) async -> HelperReply

    public init(
        protocolVersion: Int = HelperEnvelope.currentProtocolVersion,
        appVersion: String,
        requiredAccess: @escaping @Sendable (HelperEnvelope) -> [StoreKind],
        hasAccess: @escaping @Sendable (StoreKind) async -> Bool,
        route: @escaping @Sendable (HelperEnvelope) async -> HelperReply
    ) {
        self.protocolVersion = protocolVersion
        self.appVersion = appVersion
        self.requiredAccess = requiredAccess
        self.hasAccess = hasAccess
        self.route = route
    }

    public func reply(to envelope: HelperEnvelope) async -> HelperReply {
        if let mismatch = envelope.versionFailure(helperProtocol: protocolVersion, helperApp: appVersion) {
            return .failure(mismatch)
        }
        for kind in requiredAccess(envelope) where await !hasAccess(kind) {
            return .failure(.accessDenied(kind))
        }
        return await route(envelope)
    }

    /// The same, for the raw bytes the XPC listener receives.
    public func reply(to data: Data) async -> HelperReply {
        guard let envelope = try? HelperCoding.decode(HelperEnvelope.self, from: data) else {
            return .failure(.badRequest("not a Get Clear helper envelope"))
        }
        return await reply(to: envelope)
    }
}
