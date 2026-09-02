// OpenHandler.swift

import Foundation
import GetClearKit

public func handleOpen(args: [String], opener: (URL) -> Void) throws {
    do {
        _ = try parseCommand(Array(args.dropFirst()), shape: ReminderCommandShapes.open)
    } catch let e as ArgumentError {
        throw ReminderHandlerError(e.errorDescription ?? "invalid arguments")
    }
    opener(URL(fileURLWithPath: "/System/Applications/Reminders.app"))
}
