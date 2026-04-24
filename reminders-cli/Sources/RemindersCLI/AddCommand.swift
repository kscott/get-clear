// AddCommand.swift

import EventKit
import GetClearKit
import RemindersLib

func handleAdd(args: [String], store: EKEventStore) async {
    guard args.count > 1 else { fail("provide a reminder title") }
    let title = args[1]
    let allCalendars = store.calendars(for: .reminder)
    let calTitles    = allCalendars.map(\.title)
    let (listName, rawString) = splitListAndOptions(
        from: Array(args.dropFirst(2)), calendarTitles: calTitles)
    let opts = parseOptions(rawString)
    let parsedDate = opts.date.isEmpty ? nil : parseDate(opts.date)
    let recurrenceSpec: RecurrenceSpec?
    if opts.recurrence.isEmpty {
        recurrenceSpec = nil
    } else {
        guard let spec = parseRecurrence(opts.recurrence) else {
            fail("Unrecognised repeat: \"\(opts.recurrence)\"")
        }
        recurrenceSpec = spec
    }
    guard let cal = listName.flatMap({ name in allCalendars.first { $0.title == name } })
                    ?? store.defaultCalendarForNewReminders() else {
        fail("List not found: \(listName ?? "default")")
    }
    let reminder = EKReminder(eventStore: store)
    reminder.title    = title
    reminder.calendar = cal
    if let pd = parsedDate {
        let fields: Set<Calendar.Component> = pd.hasTime ? [.year, .month, .day, .hour, .minute] : [.year, .month, .day]
        reminder.dueDateComponents = Calendar.current.dateComponents(fields, from: pd.date)
    }
    if let spec = recurrenceSpec            { reminder.addRecurrenceRule(toEKRule(spec)) }
    if let p = parsePriority(opts.priority) { reminder.priority = p }
    if !opts.note.isEmpty                   { reminder.notes = opts.note }
    if !opts.url.isEmpty, let u = URL(string: opts.url) { reminder.url = u }
    commitAndLog(
        { try store.save(reminder, commit: true) },
        cmd: "add", desc: title, container: cal.title,
        confirmation: formatAddConfirmation(
            title: title, list: cal.title,
            date: parsedDate, recurrence: recurrenceSpec,
            priority: opts.priority, hasNote: !opts.note.isEmpty, url: opts.url),
        failMessage: "Could not save reminder")
}
