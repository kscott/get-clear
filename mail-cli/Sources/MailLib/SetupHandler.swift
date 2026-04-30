// SetupHandler.swift
// Pure setup helpers — identity selection logic extracted from the interactive flow.

/// Returns the email address for the selected identity.
/// `choice` is 1-based (as typed by the user); out-of-range values default to the first identity.
public func selectIdentityEmail(from identities: [MailIdentity], choice: Int) -> String {
    guard !identities.isEmpty else { return "" }
    let idx = (choice >= 1 && choice <= identities.count) ? choice - 1 : 0
    return identities[idx].email
}
