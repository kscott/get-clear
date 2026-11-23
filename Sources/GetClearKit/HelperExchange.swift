// HelperExchange.swift
//
// Turns one store call into one helper round trip, on both sides of the connection:
// HelperCaller (command side) encodes a request, sends it, and decodes the result or
// rethrows the failure; HelperResponder (helper side) decodes a request, runs it, and
// wraps the result or error as a HelperReply. Every tool's remote store and dispatch
// is built on these two, so encoding and error mapping exist exactly once.
//
// Pure: the transport is injected. See specs/018-app-bundle-identity/data-model.md.

import Foundation

/// JSON coding shared by both sides, so they can never disagree on format.
public enum HelperCoding {
    public static func encode(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(value)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}

/// The result of a store method that returns nothing.
public struct HelperNoResult: Codable, Sendable, Equatable {
    public init() {}
}

/// A store error from the helper that isn't one of the Lib's own types. Its description is the
/// helper-side error's exact text, so a command prints what a direct-access build would (FR-014).
public struct HelperStoreError: LocalizedError, Equatable {
    public let message: String

    public init(message: String) {
        self.message = message
    }

    public var errorDescription: String? {
        message
    }
}

/// A failure of the exchange itself, as opposed to the store.
public enum HelperCallError: LocalizedError, Equatable {
    case accessDenied(StoreKind)
    case versionMismatch(helperApp: String)
    case badRequest(String)
    case unreadableReply

    public var errorDescription: String? {
        switch self {
        case let .accessDenied(kind):
            kind.deniedMessage
        case let .versionMismatch(helperApp):
            "Get Clear's background helper is version \(helperApp), which doesn't match this command. Run the command again."
        case let .badRequest(reason):
            "Get Clear's background helper couldn't read the request: \(reason)"
        case .unreadableReply:
            "Get Clear's background helper sent a reply this command couldn't read."
        }
    }
}

/// Command side: sends one tool's requests and decodes the replies.
public struct HelperCaller: Sendable {
    public let tool: HelperTool
    public let appVersion: String
    public let transport: HelperTransport
    /// Decodes the tool's own store error from a `.toolError` payload; nil if it isn't one.
    public let decodeToolError: @Sendable (Data) -> Error?

    public init(
        tool: HelperTool,
        appVersion: String,
        transport: @escaping HelperTransport,
        decodeToolError: @escaping @Sendable (Data) -> Error? = { _ in nil }
    ) {
        self.tool = tool
        self.appVersion = appVersion
        self.transport = transport
        self.decodeToolError = decodeToolError
    }

    /// Sends `request` and decodes the result as `Response`.
    public func call<Response: Decodable>(
        _ request: some Encodable,
        returning _: Response.Type = Response.self
    ) async throws -> Response {
        let envelope = try HelperEnvelope(appVersion: appVersion, tool: tool, request: HelperCoding.encode(request))
        switch try await transport(envelope) {
        case let .success(data):
            guard let value = try? HelperCoding.decode(Response.self, from: data) else {
                throw HelperCallError.unreadableReply
            }
            return value
        case let .failure(failure):
            throw error(for: failure)
        }
    }

    /// Sends `request` for a store method that returns nothing.
    public func perform(_ request: some Encodable) async throws {
        _ = try await call(request, returning: HelperNoResult.self)
    }

    private func error(for failure: HelperFailure) -> Error {
        switch failure {
        case let .accessDenied(kind): HelperCallError.accessDenied(kind)
        case let .versionMismatch(_, helperApp): HelperCallError.versionMismatch(helperApp: helperApp)
        case let .toolError(data): decodeToolError(data) ?? HelperCallError.unreadableReply
        case let .storeError(message): HelperStoreError(message: message)
        case let .badRequest(reason): HelperCallError.badRequest(reason)
        }
    }
}

/// Helper side: decodes one tool's request, runs it, and wraps the outcome.
public enum HelperResponder {
    /// - Parameters:
    ///   - encodeToolError: encodes the tool's own store error; nil for any other error.
    ///   - handle: runs the decoded request against the store and returns the encoded result.
    public static func respond<Request: Decodable>(
        to data: Data,
        as _: Request.Type,
        encodeToolError: (Error) -> Data?,
        handle: (Request) async throws -> Data
    ) async -> HelperReply {
        let request: Request
        do {
            request = try HelperCoding.decode(Request.self, from: data)
        } catch {
            return .failure(.badRequest(String(describing: error)))
        }
        do {
            return try await .success(handle(request))
        } catch {
            if let encoded = encodeToolError(error) {
                return .failure(.toolError(encoded))
            }
            return .failure(.storeError(message: error.localizedDescription))
        }
    }
}
