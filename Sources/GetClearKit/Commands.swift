import Foundation

/// All commands recognized across the Get Clear suite.
///
/// Each tool declares the subset it supports via a private `Cmd` enum whose
/// `init?(_ command: Command)` maps suite commands to tool-local cases. Commands
/// not supported by a tool return `nil` from that initializer and fall through
/// to `usage()`. Adding a command to a tool requires a `Command` case here first,
/// which enforces consistent naming across the suite.
public enum Command: String {
    // Suite-wide
    case open
    case what
    case find
    case show
    case add
    case change
    case rename
    case remove
    case list
    case lists
    case send
    case draft // mail
    case setup
    // Tool-specific
    case done // reminders
    case calendars // calendar — see get-clear#31 for rename discussion
    case today // calendar
    case week // calendar
    case next // calendar
    case update // get-clear
    case recap // get-clear
    case checkUpdate = "check-update" // get-clear
}

/// Parse args, handle version/help/empty, and dispatch to `handler` with a typed `Command`.
///
/// - `.version` → prints identity and exits
/// - `.help` / `.empty` → calls `usage()`
/// - Unrecognised command string → calls `usage()`
/// - Known command → awaits `handler`, then runs UpdateChecker
///
/// The arg list passed to `handler` mirrors the raw args with flag tokens stripped;
/// the command name remains at index 0 so handler code uses `args[1]`, `args[2]`, etc.
public func runCLI(
    args: [String],
    identity: ToolIdentity,
    usage: () -> String,
    handler: (Command, [String]) async throws -> Void
) async {
    switch parseArgs(args) {
    case .version:
        print(identity)
        exit(0)
    case .help, .empty:
        print(usage())
        exit(0)
    case let .command(raw, cmdArgs):
        guard let command = Command(rawValue: raw) else { print(usage())
            exit(0)
        }
        do {
            try await handler(command, cmdArgs)
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
        UpdateChecker.spawnBackgroundCheckIfNeeded()
        if let hint = UpdateChecker.hint() { fputs(hint + "\n", stderr) }
    }
}
