// DoneRemoveCommand.swift

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

func handleRemove(args: [String], store: EKEventStore, semaphore: DispatchSemaphore) {
    withReminder(args: args, cmd: "remove", store: store, semaphore: semaphore) { reminder, title in
        let container = reminder.calendar.title
        try store.remove(reminder, commit: true)
        try? ActivityLog.write(tool: "reminders", cmd: "remove", desc: title, container: container)
        print("Removed: \(title)")
    }
}

private func withReminder(
    args: [String], cmd: String, store: EKEventStore, semaphore: DispatchSemaphore,
    action: @escaping (EKReminder, _ title: String) throws -> Void
) {
    guard args.count > 1 else { fail("provide a reminder title") }
    let title = args[1]
    let listName = args.count > 2 ? args[2] : nil
    resolveReminder(title: title, list: listName, cmd: cmd, store: store) { reminder in
        do {
            try action(reminder, title)
        } catch {
            fail("Operation failed: \(error.localizedDescription)")
        }
        semaphore.signal()
    }
}
