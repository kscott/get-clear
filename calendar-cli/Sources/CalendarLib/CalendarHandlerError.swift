// CalendarHandlerError.swift

import Foundation

public struct CalendarHandlerError: Error, CustomStringConvertible {
    public let description: String
    public init(_ message: String) {
        description = message
    }
}
