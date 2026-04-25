// StoreFactory.swift
//
// Constructs the active ContactStore backend and requests Contacts permission.

import Contacts
import GetClearKit

public func makeContactStore() async -> any ContactStore {
    let cnStore = CNContactStore()
    do {
        let granted = try await cnStore.requestAccess(for: .contacts)
        guard granted else { fail("Contacts access denied") }
    } catch {
        fail(error.localizedDescription)
    }
    return AppleContactStore(store: cnStore)
}
