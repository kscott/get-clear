// main.swift
//
// Entry point for the get-clear suite binary.
// Dispatch only — all logic lives in GetClear command handlers.

import Foundation
import GetClearKit

let args = Array(CommandLine.arguments.dropFirst())

await runCLI(args: args, identity: identity, usage: usage) { command, args in
    switch command {
    case .checkUpdate: await handleCheckUpdate()
    case .what:        await handleWhat(args: args)
    case .update:      await handleUpdate()
    case .setup:       await handleSetup()
    case .recap:       await handleRecap(args: args)
    default:           usage()
    }
}
