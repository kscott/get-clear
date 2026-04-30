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
/// - Bare words are only checked in the first position to avoid treating a
///   list or reminder named "help" as a help request.
/// - Flag-style tokens (`--help`, `-h`, `--version`, `-v`) are only valid in
///   the first position. Passing them after a command is an error — they are
///   not silently consumed as content or intercepted as a help/version request.
public func parseArgs(_ rawArgs: [String]) -> ParsedArgs {
    guard let first = rawArgs.first else { return .empty }

    // First arg: bare words and flags both redirect
    if isVersionFlag(first) { return .version }
    if isHelpFlag(first) { return .help }

    // Non-first args: flag-style tokens are invalid here
    let rest = Array(rawArgs.dropFirst())
    if let bad = rest.first(where: { isHelpFlag($0) || isVersionFlag($0) }) {
        fail("'\(bad)' is not valid after a command — use '--help' or '--version' as the first argument")
    }

    return .command(first, rawArgs)
}
