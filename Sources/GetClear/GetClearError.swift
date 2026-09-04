// GetClearError.swift
//
// Domain error type for the get-clear binary. Matches ReminderHandlerError/
// CalendarHandlerError's minimal shape (a single message, not a case
// taxonomy) — get-clear doesn't have mail/text's variety of distinct failure
// kinds, just "something went wrong, here's why," whether that's a bad
// argument or a runtime failure (network, download). Used both as
// parseCommand's wrapError target and for handlers' own runtime errors, so
// every failure path in this binary throws instead of calling fail()/exit()
// directly — only main.swift's single catch does that, matching the other
// five tools' convention.

import Foundation

struct GetClearError: Error, LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}
