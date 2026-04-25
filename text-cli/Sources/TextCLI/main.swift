// main.swift
//
// Entry point for text-bin. Argument parsing and dispatch only.

import Foundation
import AppKit
import Contacts
import TextLib
import GetClearKit

let args = Array(CommandLine.arguments.dropFirst())

await runCLI(args: args, identity: identity, usage: usage) { command, args in
    switch command {
    case .what:
        print(handleWhat(args: args))
    default:
        let store   = CNContactStore()
        let granted = await withCheckedContinuation { cont in
            store.requestAccess(for: .contacts) { ok, _ in cont.resume(returning: ok) }
        }
        let contacts = granted ? loadMessageContacts(from: store) : []
        switch command {
        case .open:
            handleOpen(args: args, contacts: contacts) { NSWorkspace.shared.open($0) }
        case .send:
            guard granted else { fail("Contacts access required") }
            do {
                print(try await handleSend(args: args, contacts: contacts, sender: makeMessageSender()))
            } catch {
                fail(error.localizedDescription)
            }
        default:
            break
        }
    }
}
