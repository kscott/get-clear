// OpenHandler.swift
// Handles the `mail open` command — opens the mail web app.

import Foundation
import GetClearKit

public func handleOpen(args: [String], opener: (URL) -> Void, config: MailConfig) throws {
    _ = try parseCommand(
        Array(args.dropFirst()), shape: MailCommandShapes.open, wrapError: MailError.badArguments
    )
    opener(config.webAppURL)
}
