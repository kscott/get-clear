// StoreFactory.swift
//
// Constructs the ContactStore a command uses (spec 018). Inside Get Clear.app, every call goes
// through the helper, which holds the Contacts permission. Anywhere else (a development build),
// the command accesses Contacts directly, as before.

import AppleContactKit
import ContactKit
import Contacts
import GetClearKit
import HelperXPC

public func makeContactStore() async -> any ContactStore {
    switch AccessRoute.current {
    case let .helper(appURL):
        return RemoteContactStore(transport: HelperClient.transport(appURL: appURL), appVersion: suiteVersion)
    case .direct:
        let cnStore = CNContactStore()
        do {
            let granted = try await cnStore.requestAccess(for: .contacts)
            guard granted else { fail("Contacts access denied") }
        } catch {
            fail(error.localizedDescription)
        }
        return AppleContactStore(store: cnStore)
    }
}
