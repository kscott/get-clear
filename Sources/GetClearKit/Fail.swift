import Darwin
import Foundation

/// Prints a red "Error:" prefix followed by the message to stderr, then exits.
/// Use for all unrecoverable errors across the Get Clear suite.
public func fail(_ msg: String) -> Never {
    fputs("\(ANSI.red("Error:")) \(msg)\n", stderr)
    exit(1)
}
