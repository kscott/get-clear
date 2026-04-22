// DoneCommand.swift

import EventKit
import GetClearKit

func handleDone(args: [String], store: EKEventStore, semaphore: DispatchSemaphore) {
    withReminder(args: args, cmd: "done", store: store, semaphore: semaphore) { reminder, title in
        reminder.isCompleted = true
        try store.save(reminder, commit: true)
        try? ActivityLog.write(tool: "reminders", cmd: "done", desc: title, container: reminder.calendar.title)
        print("Done: \(title)")
    }
}
