// StoreFactory.swift

import EventKit
import GetClearKit
import RemindersEventKit
import RemindersLib

func makeReminderStore() async -> ReminderStore {
    let ek = EKEventStore()
    do {
        let granted = try await ek.requestFullAccessToReminders()
        guard granted else { fail("Reminders access denied") }
    } catch {
        fail(error.localizedDescription)
    }
    return AppleReminderStore(ek)
}
