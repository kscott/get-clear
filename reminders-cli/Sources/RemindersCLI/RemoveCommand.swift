// RemoveCommand.swift

import EventKit
import GetClearKit

func handleRemove(args: [String], store: EKEventStore, semaphore: DispatchSemaphore) {
    withReminder(args: args, cmd: "remove", store: store, semaphore: semaphore) { reminder, title in
        let container = reminder.calendar.title
        try store.remove(reminder, commit: true)
        try? ActivityLog.write(tool: "reminders", cmd: "remove", desc: title, container: container)
        print("Removed: \(title)")
    }
}
