// OpenHandler.swift

import Foundation

public func handleOpen(opener: (URL) -> Void) {
    opener(URL(fileURLWithPath: "/System/Applications/Reminders.app"))
}
