// TextErrors.swift
//
// Domain error types for text-cli.

import Foundation

public enum TextError: Error, LocalizedError, Equatable {
    case sendFailed(String)
    case notFound(String)
    case ambiguous(String)
    case badArguments(String)

    public var errorDescription: String? {
        switch self {
        case let .sendFailed(m): "Send failed: \(m)"
        case let .notFound(q): "No contact found for \"\(q)\""
        case let .ambiguous(m): m
        case let .badArguments(m): m
        }
    }
}
