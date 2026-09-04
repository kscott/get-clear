// GetClearCommandShapes.swift
//
// CommandShape values for the get-clear binary's argument-taking commands,
// consumed by GetClearKit's shared parseCommand. Adopts the argument-shape
// rule from spec 015 (#202) — the last of the six binaries to do so.
//
// `what` is deliberately absent: consolidating it here is #197's job
// ("get-clear what [tool] [range]"), not this issue's.

import GetClearKit

enum GetClearCommandShapes {
    /// The range is optional (defaults to "today" downstream), but the parser doesn't enforce
    /// that — same pattern as calendar's `list` (FR-024: the handler validates, not the shape).
    static let recap = CommandShape(leading: .bareDateRange)

    /// No identifiers, no keywords — any token at all is a stray token.
    static let setup = CommandShape.empty

    /// No identifiers, no keywords — any token at all is a stray token.
    static let update = CommandShape.empty

    /// No identifiers, no keywords — any token at all is a stray token.
    static let checkUpdate = CommandShape.empty
}

/// Validates a zero-argument command's args against `shape` (normally `CommandShape.empty`),
/// throwing on a stray token instead of silently ignoring it. Shared by setup/update/
/// check-update; main.swift's catch turns this into the printed error.
func validateNoArguments(_ args: [String], shape: CommandShape) throws {
    _ = try parseCommand(Array(args.dropFirst()), shape: shape, wrapError: GetClearError.init)
}
