// OpenHandler.swift
// Handles the `text open` command — opens Messages.app.

import Foundation

public func handleOpen(opener: (URL) -> Void) {
    opener(URL(fileURLWithPath: "/System/Applications/Messages.app"))
}
