// main.swift
// Entry point for mail-bin. Dispatch only — all logic lives in MailLib or MailClientFactory.

import AppKit
import GetClearKit
import MailClientFactory
import MailLib

let args = Array(CommandLine.arguments.dropFirst())
let config = (try? loadConfig()) ?? MailConfig(defaultFrom: "", identities: [])

await runCLI(args: args, identity: identity, usage: usage) { command, args in
    if command == .open {
        handleOpen(opener: { NSWorkspace.shared.open($0) }, config: config)
        return
    }
    if command == .what {
        try print(handleWhat(args: args))
        return
    }

    let client = try await makeMailClient()

    switch command {
    case .setup: try await handleSetup(args: args, client: client)
    case .find: try await print(handleFind(args: args, client: client))
    case .send:
        let store = await makeStore()
        try await print(handleSend(args: args, config: config, client: client, contactStore: store))
    default:
        print(usage())
    }
}
