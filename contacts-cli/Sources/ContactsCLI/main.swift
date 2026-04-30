// main.swift
//
// Entry point for contacts-bin: permission, store construction, and command dispatch only.

import AppKit
import ContactsLib
import ContactStoreFactory
import Foundation
import GetClearKit

let args = Array(CommandLine.arguments.dropFirst())

await runCLI(args: args, identity: identity, usage: usage) { command, args in
    if command == .open {
        handleOpen(opener: { NSWorkspace.shared.open($0) })
        return
    }
    if command == .what {
        try print(handleWhat(args: args))
        return
    }

    let store = await makeContactStore()

    do {
        switch command {
        case .lists: try await print(handleLists(store: store))
        case .list: try await print(handleList(args: args, store: store))
        case .find: try await print(handleFind(args: args, store: store))
        case .show: try await print(handleShow(args: args, store: store))
        case .add: try await print(handleAdd(args: args, store: store))
        case .change: try await print(handleChange(args: args, store: store))
        case .rename: try await print(handleRename(args: args, store: store))
        case .remove: try await print(handleRemove(args: args, store: store))
        default: print(usage())
        }
    } catch {
        fail(error.localizedDescription)
    }
}
