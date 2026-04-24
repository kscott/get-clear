// RecurrenceConversion.swift
// Converts RecurrenceSpec ↔ EKRecurrenceRule at the EventKit boundary.

import EventKit
import RemindersLib

func toEKRule(_ spec: RecurrenceSpec) -> EKRecurrenceRule {
    let ekFreqs: [RecurrenceFrequency: EKRecurrenceFrequency] =
        [.daily: .daily, .weekly: .weekly, .monthly: .monthly, .yearly: .yearly]
    if let ow = spec.ordinalWeekday {
        let dow = EKRecurrenceDayOfWeek(
            dayOfTheWeek: EKWeekday(rawValue: ow.weekday)!,
            weekNumber: ow.weekNumber)
        return EKRecurrenceRule(recurrenceWith: .monthly, interval: 1,
                                daysOfTheWeek: [dow], daysOfTheMonth: nil,
                                monthsOfTheYear: nil, weeksOfTheYear: nil,
                                daysOfTheYear: nil, setPositions: nil, end: nil)
    }
    if let day = spec.dayOfMonth {
        return EKRecurrenceRule(recurrenceWith: .monthly, interval: 1,
                                daysOfTheWeek: nil, daysOfTheMonth: [NSNumber(value: day)],
                                monthsOfTheYear: nil, weeksOfTheYear: nil,
                                daysOfTheYear: nil, setPositions: nil, end: nil)
    }
    return EKRecurrenceRule(recurrenceWith: ekFreqs[spec.frequency]!, interval: spec.interval, end: nil)
}

func describeEKRule(_ rule: EKRecurrenceRule) -> String {
    describeRecurrenceRule(frequency: rule.frequency.rawValue, interval: rule.interval)
}
