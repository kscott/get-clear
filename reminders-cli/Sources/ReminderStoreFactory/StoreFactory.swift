// StoreFactory.swift
//
// Constructs the ReminderStore a command uses (spec 018). Inside Get Clear.app, every call goes
// through the helper, which holds the Reminders permission. Anywhere else (a development build),
// the command accesses Reminders directly, as before.

import EventKit
import GetClearKit
import HelperXPC
import RemindersEventKit
import RemindersLib

public func makeReminderStore() async -> any ReminderStore {
    switch AccessRoute.current {
    case let .helper(appURL):
        return RemoteReminderStore(transport: HelperClient.transport(appURL: appURL), appVersion: suiteVersion)
    case .direct:
        let ek = EKEventStore()
        do {
            let granted = try await ek.requestFullAccessToReminders()
            guard granted else { fail("Reminders access denied") }
        } catch {
            fail(error.localizedDescription)
        }
        return AppleReminderStore(ek)
    }
}
