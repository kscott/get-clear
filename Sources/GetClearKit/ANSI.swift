import Darwin
import Foundation

/// Minimal ANSI color helpers for the Get Clear suite.
///
/// Color is suppressed automatically when:
///   - stdout is not a terminal (piped, redirected, captured by completions)
///   - the NO_COLOR environment variable is set (https://no-color.org)
public enum ANSI {

    public static let enabled: Bool = {
        ProcessInfo.processInfo.environment["NO_COLOR"] == nil &&
        isatty(STDOUT_FILENO) != 0
    }()

    /// Primary identifier — name, title. Draws the eye in a list.
    public static func bold(_ s: String) -> String {
        enabled ? "\u{1B}[1m\(s)\u{1B}[0m" : s
    }

    /// Supporting detail — email, phone, date, calendar name. Recedes.
    public static func dim(_ s: String) -> String {
        enabled ? "\u{1B}[2m\(s)\u{1B}[0m" : s
    }

    /// Errors only.
    public static func red(_ s: String) -> String {
        enabled ? "\u{1B}[31m\(s)\u{1B}[0m" : s
    }
}
