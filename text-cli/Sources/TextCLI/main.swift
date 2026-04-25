// main.swift
// Entry point for text-bin. Argument parsing and dispatch only.

import Foundation
import AppKit
import GetClearKit
import TextLib

let sender = await makeMessageSender()
let args   = Array(CommandLine.arguments.dropFirst())

await runCLI(args: args, identity: identity, usage: usage) { command, args in
    switch command {
    case .what: print(handleWhat(args: args))
    case .open: handleOpen { NSWorkspace.shared.open($0) }
    case .send: print(try await handleSend(args: args, sender: sender))
    default:    print(usage())
    }
}
