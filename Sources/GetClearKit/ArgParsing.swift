import Foundation

/// Structured result of parsing raw command-line arguments.
public enum ParsedArgs {
    /// Show help and exit.
    case help
    /// Show version and exit.
    case version
    /// No arguments provided — show help.
    case empty
    /// A valid command with its arguments.
    ///
    /// `args` contains the original argument list with flag tokens stripped.
    /// The command name remains at `args[0]` so command handler code can use
    /// `args[1]`, `args[2]`, etc. without any index adjustment.
    case command(String, [String])
}

/// Parse raw CLI arguments into a structured dispatch result.
///
/// - First-position bare words (`help`, `version`) are recognised alongside
///   flag-style tokens (`--help`, `-h`, `--version`, `-v`).
/// - Flag-style tokens are intercepted from **any** position so they cannot be
///   silently consumed as content (e.g. a reminder title of "--help").
/// - Bare words are only checked in the first position to avoid treating a
///   list or reminder named "help" as a help request.
/// - All matched flag tokens are stripped from the args returned to the caller.
public func parseArgs(_ rawArgs: [String]) -> ParsedArgs {
    guard let first = rawArgs.first else { return .empty }

    // First arg: bare words and flags both redirect
    if isVersionFlag(first) { return .version }
    if isHelpFlag(first)    { return .help }

    // Non-first args: flag-style only (avoids "help" as a content word triggering this)
    let rest = Array(rawArgs.dropFirst())
    if rest.contains(where: { $0 == "--version" || $0 == "-v" }) { return .version }
    if rest.contains(where: { $0 == "--help"    || $0 == "-h" }) { return .help }

    // Strip flag tokens; command name stays at index 0 so callers need no index adjustment.
    let filtered = rawArgs.filter { $0 != "--help" && $0 != "-h" && $0 != "--version" && $0 != "-v" }
    return .command(first, filtered)
}
