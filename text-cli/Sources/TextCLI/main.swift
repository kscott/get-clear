// main.swift
// Entry point for text-bin. Argument parsing and dispatch only.

import AppKit
import Foundation
import GetClearKit
import TextLib

let args = Array(CommandLine.arguments.dropFirst())

await runCLI(args: args, identity: identity, usage: usage) { command, args in
    if command == .open {
        try handleOpen(args: args, opener: { NSWorkspace.shared.open($0) })
        return
    }

    do {
        switch command {
        case .what: print(handleWhat(args: args))
        case .send:
            let sender = await makeMessageSender()
            try await print(handleSend(args: args, sender: sender))
        default: print(usage())
        }
    } catch {
        fail(error.localizedDescription)
    }
}
