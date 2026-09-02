// OpenHandler.swift

import Foundation
import GetClearKit

public func handleOpen(args: [String], opener: (URL) -> Void) throws {
    _ = try parseCommand(
        Array(args.dropFirst()), shape: ReminderCommandShapes.open, wrapError: ReminderHandlerError.init
    )
    opener(URL(fileURLWithPath: "/System/Applications/Reminders.app"))
}
