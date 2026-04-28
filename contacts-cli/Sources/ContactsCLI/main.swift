// main.swift
//
// Entry point for contacts-bin: permission, store construction, and command dispatch only.

import Foundation
import AppKit
import ContactsLib
import ContactStoreFactory
import GetClearKit

let args = Array(CommandLine.arguments.dropFirst())

Task { await runCLI(args: args, identity: identity, usage: usage) { command, args in
    let store = try await makeContactStore()

    switch command {
    case .open:   print(handleOpen(opener: { NSWorkspace.shared.open($0) }))
    case .what:   print(try handleWhat(args: args))
    case .lists:  print(try await handleLists(store: store))
    case .list:   print(try await handleList(args: args, store: store))
case .find:   print(try await handleFind(args: args, store: store))
    case .show:   print(try await handleShow(args: args, store: store))
    case .add:    print(try await handleAdd(args: args, store: store))
    case .change: print(try await handleChange(args: args, store: store))
    case .rename: print(try await handleRename(args: args, store: store))
    case .remove: print(try await handleRemove(args: args, store: store))
    default:      print(usage())
    }
} }
