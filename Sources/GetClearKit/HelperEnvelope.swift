// HelperEnvelope.swift
//
// The wire format between a Get Clear command and the Get Clear helper (spec 018).
// Pure Codable values. The XPC boundary moves them as opaque JSON Data, so every
// request and reply is a plain value that can be tested without a connection.
//
// See specs/018-app-bundle-identity/contracts/helper-protocol.md.

import Foundation

/// Which tool's request an envelope carries; the helper routes on it.
public enum HelperTool: String, Codable, Sendable, Equatable {
    case reminders
    case calendar
    case contacts
    case text
    case getClear
}

/// One privacy permission Get Clear holds. Exactly the four in FR-003.
public enum StoreKind: String, Codable, Sendable, Equatable, CaseIterable {
    case reminders
    case calendars
    case contacts
    case messages

    /// The message a command prints when the user has denied this permission (FR-005).
    public var deniedMessage: String {
        switch self {
        case .reminders:
            "Get Clear doesn't have access to Reminders. "
                + "Turn it on in System Settings → Privacy & Security → Reminders → Get Clear."
        case .calendars:
            "Get Clear doesn't have access to Calendars. "
                + "Turn it on in System Settings → Privacy & Security → Calendars → Get Clear."
        case .contacts:
            "Get Clear doesn't have access to Contacts. "
                + "Turn it on in System Settings → Privacy & Security → Contacts → Get Clear."
        case .messages:
            "Get Clear doesn't have permission to control Messages. "
                + "Turn it on in System Settings → Privacy & Security → Automation → Get Clear → Messages."
        }
    }
}

public extension HelperTool {
    /// The permission a tool's requests need before the helper touches a store.
    /// `getClear` carries control requests, which name their own permission.
    var storeKind: StoreKind? {
        switch self {
        case .reminders: .reminders
        case .calendar: .calendars
        case .contacts: .contacts
        case .text: .messages
        case .getClear: nil
        }
    }
}

/// One request from a command to the helper.
public struct HelperEnvelope: Codable, Sendable, Equatable {
    /// Bumped when the wire format changes incompatibly.
    public static let currentProtocolVersion = 1

    public let protocolVersion: Int
    public let appVersion: String
    public let tool: HelperTool
    /// A tool-specific request (e.g. `ReminderHelperRequest`), JSON-encoded.
    public let request: Data

    public init(protocolVersion: Int = currentProtocolVersion, appVersion: String, tool: HelperTool, request: Data) {
        self.protocolVersion = protocolVersion
        self.appVersion = appVersion
        self.tool = tool
        self.request = request
    }

    /// The failure the helper returns when this envelope came from a different build (contract C2),
    /// or nil when sender and helper match.
    public func versionFailure(helperProtocol: Int, helperApp: String) -> HelperFailure? {
        guard protocolVersion == helperProtocol, appVersion == helperApp else {
            return .versionMismatch(helperProtocol: helperProtocol, helperApp: helperApp)
        }
        return nil
    }
}

/// The helper's answer to one envelope.
public enum HelperReply: Codable, Sendable, Equatable {
    /// A tool-specific result, JSON-encoded.
    case success(Data)
    case failure(HelperFailure)
}

public enum HelperFailure: Codable, Sendable, Equatable {
    /// The user denied this permission (FR-005).
    case accessDenied(StoreKind)
    /// The helper is a different build from the command; the client restarts it and retries once.
    case versionMismatch(helperProtocol: Int, helperApp: String)
    /// The Lib's own store error (e.g. `ReminderStoreError`), JSON-encoded, rethrown typed on the client.
    case toolError(Data)
    /// Any other store error, carried as its exact description so stderr wording is unchanged (FR-014).
    case storeError(message: String)
    /// An undecodable or unknown request. A defect, never user-caused.
    case badRequest(String)
}

/// Requests that belong to no tool: liveness and permission checks.
public enum HelperControlRequest: Codable, Sendable, Equatable {
    case ping
    case requestAccess(StoreKind)
}

/// Sends one envelope to the helper and returns its reply. The XPC boundary supplies the real one;
/// tests supply a closure that calls the helper-side dispatch directly.
public typealias HelperTransport = @Sendable (HelperEnvelope) async throws -> HelperReply
