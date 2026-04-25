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
        case .sendFailed(let m):   return "Send failed: \(m)"
        case .notFound(let q):     return "No contact found for \"\(q)\""
        case .ambiguous(let m):    return m
        case .badArguments(let m): return m
        }
    }
}
