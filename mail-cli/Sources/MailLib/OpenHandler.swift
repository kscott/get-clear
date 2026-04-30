// OpenHandler.swift
// Handles the `mail open` command — opens the mail web app.

import Foundation

public func handleOpen(opener: (URL) -> Void, config: MailConfig) {
    opener(config.webAppURL)
}
