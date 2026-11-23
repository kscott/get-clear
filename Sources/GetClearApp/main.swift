// main.swift
//
// Get Clear.app's executable. launchd runs it as the helper (`serve`); the PKG and the commands
// run `register` / `unregister`. Opened from Finder, it says where Get Clear actually lives.
// These subcommands are internal and never listed in any usage text.

import Foundation
import HelperXPC

switch CommandLine.arguments.dropFirst().first {
case "serve":
    HelperService(gate: HelperRouting.gate()).run()
case "register":
    exit(AppRegistration.register())
case "unregister":
    exit(AppRegistration.unregister())
case nil:
    print("Get Clear runs from Terminal. Try `reminders --help`.")
    exit(0)
case let other?:
    FileHandle.standardError.write(Data("Get Clear: unknown subcommand '\(other)'.\n".utf8))
    exit(1)
}
