// main.swift
//
// Entry point for the get-clear suite binary.
// Dispatch only — all logic lives in GetClear command handlers.

import Foundation
import GetClearKit

let args     = Array(CommandLine.arguments.dropFirst())

let dispatch = parseArgs(args)
if case .version = dispatch { print(identity); exit(0) }
guard case .command(let cmd, let cmdArgs) = dispatch else { usage() }

switch cmd {
case "check-update":  handleCheckUpdate()
case "what":          handleWhat(args: cmdArgs)
case "update":        handleUpdate()
case "setup":         handleSetup()
case "recap":         handleRecap(args: cmdArgs)
default:              usage()
}
