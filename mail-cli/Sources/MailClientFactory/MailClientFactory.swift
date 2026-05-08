// MailClientFactory.swift
// Backend selection for mail — returns any MailClient from the configured backend.

import Foundation
import MailJMAP
import MailLib

/// Connect using the token stored in Keychain.
public func makeMailClient() async throws -> any MailClient {
    let token = try loadToken()
    return try await makeMailClient(token: token)
}

/// Connect using an explicit token (used during setup before Keychain is written).
public func makeMailClient(token: String) async throws -> any MailClient {
    try await JMAPClient.connect(token: token)
}

/// Load the stored backend credential. Returns nil if none exists.
public func loadMailCredential() -> String? {
    try? loadToken()
}

/// Store a backend credential. Called by setup after the user provides a token.
public func saveMailCredential(_ token: String) throws {
    try storeToken(token)
}

public let configURL: URL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".config/mail-cli/config.toml")

public func loadConfig(from url: URL = configURL) throws -> MailConfig {
    do {
        let content = try String(contentsOf: url, encoding: .utf8)
        return parseConfig(content)
    } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
        throw MailError.noConfig
    }
}

public func saveConfig(_ config: MailConfig, to url: URL = configURL) throws {
    let content = serializeConfig(config)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
    try content.write(to: url, atomically: true, encoding: .utf8)
}
