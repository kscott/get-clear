// main.swift
//
// Entry point for the get-clear suite binary.
// Dispatch only — all logic lives in GetClear command handlers.

import Foundation
import GetClearKit

let args = Array(CommandLine.arguments.dropFirst())

await runCLI(args: args, identity: identity, usage: usage) { command, args in
    do {
        switch command {
        case .checkUpdate: try await handleCheckUpdate(args: args)
        case .what: await handleWhat(args: args)
        case .update: try await handleUpdate(args: args)
        case .setup: try await handleSetup(args: args)
        case .recap: try await handleRecap(args: args)
        default: print(usage())
        }
    } catch {
        fail(error.localizedDescription)
    }
}
