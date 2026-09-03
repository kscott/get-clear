// OpenHandler.swift

import Foundation
import GetClearKit

public func handleOpen(args: [String], opener: (URL) -> Void) throws -> String {
    _ = try parseCommand(
        Array(args.dropFirst()), shape: CalendarCommandShapes.open, wrapError: CalendarHandlerError.init
    )
    opener(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
    return ""
}
