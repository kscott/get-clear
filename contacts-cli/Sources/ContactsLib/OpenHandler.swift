import Foundation
import GetClearKit

public func handleOpen(args: [String], opener: (URL) -> Void) throws {
    _ = try parseCommand(
        Array(args.dropFirst()), shape: ContactCommandShapes.open, wrapError: ContactHandlerError.usage
    )
    opener(URL(fileURLWithPath: "/System/Applications/Contacts.app"))
}
