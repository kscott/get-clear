// main.swift
// Entry point for mail-bin. Dispatch only — all logic lives in MailLib or MailClientFactory.

import AppKit
import MailLib
import MailClientFactory
import GetClearKit

let args   = Array(CommandLine.arguments.dropFirst())
let config = (try? loadConfig()) ?? MailConfig(defaultFrom: "", identities: [])

await runCLI(args: args, identity: identity, usage: usage) { command, args in
    if command == .open {
        handleOpen(opener: { NSWorkspace.shared.open($0) }, config: config)
        return
    }
    if command == .what {
        print(try handleWhat(args: args))
        return
    }

    let client = try await makeMailClient()

    switch command {
    case .setup: try await handleSetup(args: args, client: client)
    case .find:  print(try await handleFind(args: args, client: client))
    case .send:
        let store = await makeStore()
        print(try await handleSend(args: args, config: config, client: client, contactStore: store))
    default:
        print(usage())
    }
}
