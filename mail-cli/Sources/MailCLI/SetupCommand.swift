// SetupCommand.swift
// Interactive setup: token prompting, identity selection, Keychain storage, config write.

import Foundation
import GetClearKit
import MailClientFactory
import MailLib

func handleSetup(args: [String]) async throws {
    let token: String
    if args.count > 1 {
        token = args[1]
    } else if let existing = loadMailCredential() {
        token = existing
    } else {
        print("Enter your Fastmail JMAP token: ", terminator: "")
        fflush(stdout)
        guard let t = readLine(strippingNewline: true), !t.isEmpty else {
            throw MailError.jmapError("No token provided")
        }
        token = t
    }

    let client = try await makeMailClient(token: token)
    print("Fetching identities...")
    let identities = try await client.fetchIdentities()

    let defaultFrom: String
    if identities.count == 1 {
        defaultFrom = identities[0].email
    } else {
        print("\nAvailable identities:")
        for (i, id) in identities.enumerated() {
            print("  \(i + 1)  \(id.displayLabel)")
        }
        print("\nDefault identity [1]: ", terminator: "")
        fflush(stdout)
        let input = readLine(strippingNewline: true)?.trimmingCharacters(in: .whitespaces) ?? ""
        let choice = Int(input) ?? 1
        defaultFrom = selectIdentityEmail(from: identities, choice: choice)
    }

    try saveMailCredential(token)
    try saveConfig(MailConfig(defaultFrom: defaultFrom, identities: identities))

    print("Setup complete. Found \(identities.count) \(identities.count == 1 ? "identity" : "identities"):")
    for id in identities {
        let marker = id.email == defaultFrom ? " ← default" : ""
        print("  \(id.displayLabel)\(marker)")
    }
}
