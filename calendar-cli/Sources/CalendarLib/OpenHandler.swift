// OpenHandler.swift

import Foundation

public func handleOpen(opener: (URL) -> Void) -> String {
    opener(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
    return ""
}
