// RecurrenceParsingSpec.swift
//
// Tests for RecurrenceParsing — natural-language recurrence string parsing.

import Foundation
import RemindersLib
import Testing

@Suite("parseRecurrence")
struct ParseRecurrenceTests {
    @Suite("simple keywords")
    struct SimpleKeywords {
        @Test("parses 'daily'") func daily() {
            #expect(parseRecurrence("daily")?.frequency == .daily)
        }

        @Test("parses 'weekly'") func weekly() {
            #expect(parseRecurrence("weekly")?.frequency == .weekly)
        }

        @Test("parses 'monthly'") func monthly() {
            #expect(parseRecurrence("monthly")?.frequency == .monthly)
        }

        @Test("parses 'yearly'") func yearly() {
            #expect(parseRecurrence("yearly")?.frequency == .yearly)
        }

        @Test("parses 'annually' as yearly") func annually() {
            #expect(parseRecurrence("annually")?.frequency == .yearly)
        }

        @Test("parses 'every day' as daily") func everyDay() {
            #expect(parseRecurrence("every day")?.frequency == .daily)
        }

        @Test("parses 'every week' as weekly") func everyWeek() {
            #expect(parseRecurrence("every week")?.frequency == .weekly)
        }

        @Test("parses 'every month' as monthly") func everyMonth() {
            #expect(parseRecurrence("every month")?.frequency == .monthly)
        }

        @Test("parses 'every year' as yearly") func everyYear() {
            #expect(parseRecurrence("every year")?.frequency == .yearly)
        }

        @Test("simple keywords produce interval of 1") func interval1() {
            #expect(parseRecurrence("weekly")?.interval == 1)
        }

        @Test("simple keywords produce no ordinal weekday") func noOrdinal() {
            #expect(parseRecurrence("weekly")?.ordinalWeekday == nil)
        }

        @Test("returns nil for unrecognized input") func nilForUnrecognized() {
            #expect(parseRecurrence("banana") == nil)
        }
    }

    @Suite("intervals")
    struct Intervals {
        @Test("'every 2 weeks' has weekly frequency") func every2WeeksFreq() {
            #expect(parseRecurrence("every 2 weeks")?.frequency == .weekly)
        }

        @Test("'every 2 weeks' has interval 2") func every2WeeksInterval() {
            #expect(parseRecurrence("every 2 weeks")?.interval == 2)
        }

        @Test("'every 3 months' has monthly frequency") func every3MonthsFreq() {
            #expect(parseRecurrence("every 3 months")?.frequency == .monthly)
        }

        @Test("'every 3 months' has interval 3") func every3MonthsInterval() {
            #expect(parseRecurrence("every 3 months")?.interval == 3)
        }

        @Test("'every 6 days' has daily frequency") func every6DaysFreq() {
            #expect(parseRecurrence("every 6 days")?.frequency == .daily)
        }

        @Test("'every 6 days' has interval 6") func every6DaysInterval() {
            #expect(parseRecurrence("every 6 days")?.interval == 6)
        }

        @Test("'every 2 years' has yearly frequency") func every2YearsFreq() {
            #expect(parseRecurrence("every 2 years")?.frequency == .yearly)
        }

        @Test("'every 2 years' has interval 2") func every2YearsInterval() {
            #expect(parseRecurrence("every 2 years")?.interval == 2)
        }
    }

    @Suite("ordinal weekday — word")
    struct OrdinalWeekdayWord {
        @Test("'last tuesday' is monthly") func lastTuesdayMonthly() {
            #expect(parseRecurrence("last tuesday")?.frequency == .monthly)
        }

        @Test("'last tuesday' has weekNumber -1") func lastTuesdayWeekNumber() {
            #expect(parseRecurrence("last tuesday")?.ordinalWeekday?.weekNumber == -1)
        }

        @Test("'last tuesday' has weekday 3") func lastTuesdayWeekday() {
            #expect(parseRecurrence("last tuesday")?.ordinalWeekday?.weekday == 3)
        }

        @Test("'first friday' has weekNumber 1") func firstFridayWeekNumber() {
            #expect(parseRecurrence("first friday")?.ordinalWeekday?.weekNumber == 1)
        }

        @Test("'first friday' has weekday 6") func firstFridayWeekday() {
            #expect(parseRecurrence("first friday")?.ordinalWeekday?.weekday == 6)
        }

        @Test("'second monday' has weekNumber 2") func secondMondayWeekNumber() {
            #expect(parseRecurrence("second monday")?.ordinalWeekday?.weekNumber == 2)
        }

        @Test("'second monday' has weekday 2") func secondMondayWeekday() {
            #expect(parseRecurrence("second monday")?.ordinalWeekday?.weekday == 2)
        }

        @Test("'third wednesday' has weekNumber 3") func thirdWednesdayWeekNumber() {
            #expect(parseRecurrence("third wednesday")?.ordinalWeekday?.weekNumber == 3)
        }

        @Test("'third wednesday' has weekday 4") func thirdWednesdayWeekday() {
            #expect(parseRecurrence("third wednesday")?.ordinalWeekday?.weekday == 4)
        }

        @Test("'fourth sunday' has weekNumber 4") func fourthSundayWeekNumber() {
            #expect(parseRecurrence("fourth sunday")?.ordinalWeekday?.weekNumber == 4)
        }

        @Test("'fourth sunday' has weekday 1") func fourthSundayWeekday() {
            #expect(parseRecurrence("fourth sunday")?.ordinalWeekday?.weekday == 1)
        }

        @Test("leading article 'the' is ignored") func leadingThe() {
            #expect(parseRecurrence("the last wednesday")?.ordinalWeekday?.weekNumber == -1)
        }

        @Test("leading phrase 'on the' is ignored") func leadingOnThe() {
            #expect(parseRecurrence("on the first friday")?.ordinalWeekday?.weekNumber == 1)
        }
    }

    @Suite("ordinal weekday — numeric")
    struct OrdinalWeekdayNumeric {
        @Test("'1st monday' has weekNumber 1") func firstMondayWeekNumber() {
            #expect(parseRecurrence("1st monday")?.ordinalWeekday?.weekNumber == 1)
        }

        @Test("'1st monday' has weekday 2") func firstMondayWeekday() {
            #expect(parseRecurrence("1st monday")?.ordinalWeekday?.weekday == 2)
        }

        @Test("'2nd wednesday' has weekNumber 2") func secondWednesdayWeekNumber() {
            #expect(parseRecurrence("2nd wednesday")?.ordinalWeekday?.weekNumber == 2)
        }

        @Test("'2nd wednesday' has weekday 4") func secondWednesdayWeekday() {
            #expect(parseRecurrence("2nd wednesday")?.ordinalWeekday?.weekday == 4)
        }

        @Test("'3rd friday' has weekNumber 3") func thirdFridayWeekNumber() {
            #expect(parseRecurrence("3rd friday")?.ordinalWeekday?.weekNumber == 3)
        }

        @Test("'3rd friday' has weekday 6") func thirdFridayWeekday() {
            #expect(parseRecurrence("3rd friday")?.ordinalWeekday?.weekday == 6)
        }

        @Test("'4th thursday' has weekNumber 4") func fourthThursdayWeekNumber() {
            #expect(parseRecurrence("4th thursday")?.ordinalWeekday?.weekNumber == 4)
        }

        @Test("'4th thursday' has weekday 5") func fourthThursdayWeekday() {
            #expect(parseRecurrence("4th thursday")?.ordinalWeekday?.weekday == 5)
        }
    }

    @Suite("day of month")
    struct DayOfMonth {
        @Test("'the 1st' is monthly") func the1stMonthly() {
            #expect(parseRecurrence("the 1st")?.frequency == .monthly)
        }

        @Test("'the 1st' has dayOfMonth 1") func the1stDay() {
            #expect(parseRecurrence("the 1st")?.dayOfMonth == 1)
        }

        @Test("'the 15th' has dayOfMonth 15") func the15thDay() {
            #expect(parseRecurrence("the 15th")?.dayOfMonth == 15)
        }

        @Test("'on the 22nd' has dayOfMonth 22") func onThe22ndDay() {
            #expect(parseRecurrence("on the 22nd")?.dayOfMonth == 22)
        }

        @Test("'2nd of the month' has dayOfMonth 2") func secondOfMonthDay() {
            #expect(parseRecurrence("2nd of the month")?.dayOfMonth == 2)
        }

        @Test("'on the 1st of the month' has dayOfMonth 1") func onThe1stOfMonthDay() {
            #expect(parseRecurrence("on the 1st of the month")?.dayOfMonth == 1)
        }

        @Test("'the 29th' has dayOfMonth 29") func the29thDay() {
            #expect(parseRecurrence("the 29th")?.dayOfMonth == 29)
        }

        @Test("'the 30th' has dayOfMonth 30") func the30thDay() {
            #expect(parseRecurrence("the 30th")?.dayOfMonth == 30)
        }

        @Test("'the 31st' has dayOfMonth 31") func the31stDay() {
            #expect(parseRecurrence("the 31st")?.dayOfMonth == 31)
        }

        @Test("day 32 is rejected") func day32Rejected() {
            #expect(parseRecurrence("the 32nd") == nil)
        }

        @Test("day 0 is rejected") func day0Rejected() {
            #expect(parseRecurrence("the 0th") == nil)
        }

        @Test("'last day of the month' returns nil — not yet supported") func lastDayNotSupported() {
            #expect(parseRecurrence("last day of the month") == nil)
        }

        @Test("'end of month' returns nil — not yet supported") func endOfMonthNotSupported() {
            #expect(parseRecurrence("end of month") == nil)
        }

        @Test("'2nd wednesday' is not treated as day-of-month") func secondWednesdayNotDayOfMonth() {
            #expect(parseRecurrence("2nd wednesday")?.dayOfMonth == nil)
        }

        @Test("'2nd wednesday' is treated as ordinal weekday") func secondWednesdayIsOrdinal() {
            #expect(parseRecurrence("2nd wednesday")?.ordinalWeekday != nil)
        }
    }
}

@Suite("splitOnRepeat")
struct SplitOnRepeatTests {
    @Suite("keyword variants")
    struct KeywordVariants {
        @Test("'repeat' splits date from recurrence")
        func repeatSplits() {
            let r = splitOnRepeat("march 1 repeat monthly")
            #expect(r.date == "march 1")
            #expect(r.recurrence == "monthly")
        }

        @Test("'repeats' variant splits correctly")
        func repeatsVariant() {
            let r = splitOnRepeat("march 1 repeats monthly")
            #expect(r.date == "march 1")
            #expect(r.recurrence == "monthly")
        }

        @Test("'repeating' variant splits correctly")
        func repeatingVariant() {
            let r = splitOnRepeat("march 1 repeating monthly")
            #expect(r.date == "march 1")
            #expect(r.recurrence == "monthly")
        }

        @Test("'repeated' variant splits correctly")
        func repeatedVariant() {
            let r = splitOnRepeat("march 1 repeated monthly")
            #expect(r.date == "march 1")
            #expect(r.recurrence == "monthly")
        }
    }

    @Suite("keyword position")
    struct KeywordPosition {
        @Test("keyword before any date leaves date empty")
        func keywordBeforeDateEmptyDate() {
            #expect(splitOnRepeat("repeat daily").date == "")
        }

        @Test("keyword before any date captures recurrence")
        func keywordBeforeDateCapturesRecurrence() {
            #expect(splitOnRepeat("repeat daily").recurrence == "daily")
        }

        @Test("keyword after date+time splits correctly")
        func keywordAfterDateTime() {
            let r = splitOnRepeat("tuesday at 3pm repeating weekly")
            #expect(r.date == "tuesday at 3pm")
            #expect(r.recurrence == "weekly")
        }

        @Test("no keyword returns full string as date")
        func noKeywordFullString() {
            #expect(splitOnRepeat("tuesday at 3pm").date == "tuesday at 3pm")
        }

        @Test("no keyword returns empty recurrence")
        func noKeywordEmptyRecurrence() {
            #expect(splitOnRepeat("tuesday at 3pm").recurrence == "")
        }

        @Test("ordinal recurrence after keyword is captured")
        func ordinalRecurrenceCaptured() {
            #expect(splitOnRepeat("repeating last tuesday").recurrence == "last tuesday")
        }
    }
}

@Suite("describeRecurrenceRule")
struct DescribeRecurrenceRuleTests {
    @Suite("simple frequencies")
    struct SimpleFrequencies {
        @Test("describes daily (frequency 0)") func daily() {
            #expect(describeRecurrenceRule(frequency: 0, interval: 1) == "daily")
        }

        @Test("describes weekly (frequency 1)") func weekly() {
            #expect(describeRecurrenceRule(frequency: 1, interval: 1) == "weekly")
        }

        @Test("describes monthly (frequency 2)") func monthly() {
            #expect(describeRecurrenceRule(frequency: 2, interval: 1) == "monthly")
        }

        @Test("describes yearly (frequency 3)") func yearly() {
            #expect(describeRecurrenceRule(frequency: 3, interval: 1) == "yearly")
        }
    }

    @Suite("intervals greater than one")
    struct IntervalsGreaterThanOne {
        @Test("describes every N weeks") func everyNWeeks() {
            #expect(describeRecurrenceRule(frequency: 1, interval: 2) == "every 2 weeks")
        }

        @Test("describes every N months") func everyNMonths() {
            #expect(describeRecurrenceRule(frequency: 2, interval: 3) == "every 3 months")
        }
    }

    @Suite("unknown frequency")
    struct UnknownFrequency {
        @Test("returns 'repeating' for unrecognized frequency value")
        func repeatingForUnknown() {
            #expect(describeRecurrenceRule(frequency: 99, interval: 1) == "repeating")
        }
    }
}

@Suite("describeRecurrence")
struct DescribeRecurrenceTests {
    @Suite("simple frequencies")
    struct SimpleFrequencies {
        @Test("describes daily") func daily() {
            #expect(describeRecurrence(RecurrenceSpec(frequency: .daily, interval: 1)) == "repeat daily")
        }

        @Test("describes weekly") func weekly() {
            #expect(describeRecurrence(RecurrenceSpec(frequency: .weekly, interval: 1)) == "repeat weekly")
        }

        @Test("describes monthly") func monthly() {
            #expect(describeRecurrence(RecurrenceSpec(frequency: .monthly, interval: 1)) == "repeat monthly")
        }

        @Test("describes yearly") func yearly() {
            #expect(describeRecurrence(RecurrenceSpec(frequency: .yearly, interval: 1)) == "repeat yearly")
        }
    }

    @Suite("intervals")
    struct IntervalsSuite {
        @Test("describes interval > 1")
        func intervalGreaterThanOne() {
            #expect(describeRecurrence(RecurrenceSpec(frequency: .weekly, interval: 2)) == "repeat every 2 weeks")
        }
    }

    @Suite("ordinal weekday")
    struct OrdinalWeekday {
        @Test("describes last tuesday of the month")
        func lastTuesday() {
            let spec = RecurrenceSpec(frequency: .monthly, interval: 1,
                                      ordinalWeekday: .init(weekday: 3, weekNumber: -1))
            #expect(describeRecurrence(spec) == "repeat last tuesday of the month")
        }

        @Test("describes first friday of the month")
        func firstFriday() {
            let spec = RecurrenceSpec(frequency: .monthly, interval: 1,
                                      ordinalWeekday: .init(weekday: 6, weekNumber: 1))
            #expect(describeRecurrence(spec) == "repeat first friday of the month")
        }
    }

    @Suite("day of month")
    struct DayOfMonth {
        @Test("describes 1st of the month")
        func first() {
            let spec = RecurrenceSpec(frequency: .monthly, interval: 1, dayOfMonth: 1)
            #expect(describeRecurrence(spec) == "repeat on the 1st of the month")
        }

        @Test("describes 15th of the month")
        func fifteenth() {
            let spec = RecurrenceSpec(frequency: .monthly, interval: 1, dayOfMonth: 15)
            #expect(describeRecurrence(spec) == "repeat on the 15th of the month")
        }

        @Test("describes 22nd of the month")
        func twentySecond() {
            let spec = RecurrenceSpec(frequency: .monthly, interval: 1, dayOfMonth: 22)
            #expect(describeRecurrence(spec) == "repeat on the 22nd of the month")
        }

        @Test("describes 3rd of the month")
        func third() {
            let spec = RecurrenceSpec(frequency: .monthly, interval: 1, dayOfMonth: 3)
            #expect(describeRecurrence(spec) == "repeat on the 3rd of the month")
        }
    }
}
