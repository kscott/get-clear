// OpenHandler.swift
// Handles the `text open` command — opens Messages.app.

import Foundation
import GetClearKit

public func handleOpen(args: [String], opener: (URL) -> Void) throws {
    _ = try parseCommand(
        Array(args.dropFirst()), shape: TextCommandShapes.open, wrapError: TextError.badArguments
    )
    opener(URL(fileURLWithPath: "/System/Applications/Messages.app"))
}
