import Foundation

public enum ContactHandlerError: Error {
    case usage(String)
}

extension ContactHandlerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .usage(msg): msg
        }
    }
}
