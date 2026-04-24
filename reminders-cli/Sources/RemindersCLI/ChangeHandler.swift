// ChangeHandler.swift

import EventKit
import GetClearKit
import RemindersLib

func handleChange(args: [String], store: EKEventStore) async {
    guard args.count > 1 else { fail("provide a reminder title") }
    let title = args[1]
    let allCalendars = store.calendars(for: .reminder)
    let (listName, newDateRepeat) = splitListAndOptions(
        from: Array(args.dropFirst(2)), calendarTitles: allCalendars.map(\.title))
    let reminder = await resolveReminder(title: title, list: listName, cmd: "change",
                                         calendars: allCalendars, store: store)
    let opts = parseOptions(newDateRepeat)
    let reminderChanges: ReminderChanges
    do {
        reminderChanges = try parseReminderChanges(opts, existingDue: reminder.dueDateComponents)
    } catch ReminderChangeError.nothingToChange {
        fail("nothing to change — specify a date, repeat, priority, note, url, or list")
    } catch ReminderChangeError.unrecognizedRecurrence(let s) {
        fail("Unrecognised repeat: \"\(s)\"")
    } catch {
        fail("Change failed: \(error.localizedDescription)")
    }
    let descriptions = applyChanges(reminderChanges, to: reminder, store: store)
    commitAndLog(
        { try store.save(reminder, commit: true) },
        cmd: "change", desc: title, container: reminder.calendar.title,
        confirmation: "Updated \"\(title)\": \(descriptions.joined(separator: ", "))")
}
