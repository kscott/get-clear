// MailErrors.swift
//
// Domain error types for mail-cli.

import Foundation

public enum MailError: Error, LocalizedError {
    case noToken
    case noConfig
    case noMatchingIdentity(String)
    case sendFailed(String)
    case notFound(String)
    case jmapError(String)
    /// Argument-shape errors from the shared parser (parseCommand's wrapError target) — distinct
    /// from sendFailed, which is a runtime send/resolution failure, not a parsing one.
    case badArguments(String)

    public var errorDescription: String? {
        switch self {
        case .noToken: "No JMAP token — run 'mail setup' first"
        case .noConfig: "No config — run 'mail setup' first"
        case let .noMatchingIdentity(e): "No identity found for '\(e)' — run 'mail setup' to refresh"
        case let .sendFailed(m): "Send failed: \(m)"
        case let .notFound(q): "Not found: \(q)"
        case let .jmapError(m): "JMAP error: \(m)"
        case let .badArguments(m): m
        }
    }
}
