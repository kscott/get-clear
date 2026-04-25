// OpenHandler.swift

import Foundation

public func handleOpen(args: [String], contacts: [MessageContact], opener: (URL) -> Void) {
    if args.count > 1 {
        let query = args.dropFirst().joined(separator: " ")
        if let target = resolveSendTarget(query, contacts: contacts),
           let url = URL(string: "sms:\(target.address)") {
            opener(url)
            return
        }
    }
    opener(URL(fileURLWithPath: "/System/Applications/Messages.app"))
}
