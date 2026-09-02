// OptionsParsingSpec.swift
//
// Tests for OptionsParsing — combined options string parsing into individual fields.

import Foundation
import RemindersLib
import Testing

@Suite("parseOptions")
struct OptionsParsingTests {
    @Suite("date only")
    struct DateOnly {
        @Test("captures date when no other keywords present")
        func capturesDate() {
            #expect(parseOptions("friday at 3pm").date == "friday at 3pm")
        }

        @Test("leaves recurrence empty when no repeat keyword")
        func recurrenceEmpty() {
            #expect(parseOptions("friday at 3pm").recurrence == "")
        }

        @Test("leaves priority empty when no priority keyword")
        func priorityEmpty() {
            #expect(parseOptions("friday at 3pm").priority == "")
        }

        @Test("leaves note empty when no note keyword")
        func noteEmpty() {
            #expect(parseOptions("friday at 3pm").note == "")
        }

        @Test("leaves url empty when no url keyword")
        func urlEmpty() {
            #expect(parseOptions("friday at 3pm").url == "")
        }
    }

    @Suite("repeat keyword")
    struct RepeatKeyword {
        @Test("captures recurrence after repeat keyword")
        func capturesRecurrence() {
            #expect(parseOptions("march 1 repeat monthly").recurrence == "monthly")
        }

        @Test("captures date before repeat keyword")
        func capturesDateBeforeRepeat() {
            #expect(parseOptions("march 1 repeat monthly").date == "march 1")
        }
    }

    @Suite("priority keyword")
    struct PriorityKeyword {
        @Test("captures 'high'") func high() {
            #expect(parseOptions("priority high").priority == "high")
        }

        @Test("captures 'medium'") func medium() {
            #expect(parseOptions("priority medium").priority == "medium")
        }

        @Test("captures 'low'") func low() {
            #expect(parseOptions("priority low").priority == "low")
        }

        @Test("captures 'none'") func none() {
            #expect(parseOptions("priority none").priority == "none")
        }
    }

    @Suite("url keyword")
    struct UrlKeyword {
        @Test("captures url value")
        func capturesURL() {
            #expect(parseOptions("url https://example.com").url == "https://example.com")
        }

        @Test("leaves date empty when only url present")
        func dateEmptyWithOnlyURL() {
            #expect(parseOptions("url https://example.com").date == "")
        }
    }

    @Suite("note keyword")
    struct NoteKeyword {
        @Test("captures note text to end of string")
        func capturesNoteToEnd() {
            #expect(parseOptions("tomorrow note pick up dry cleaning priority urgent").note
                == "pick up dry cleaning priority urgent")
        }

        @Test("captures date before note keyword")
        func capturesDateBeforeNote() {
            #expect(parseOptions("tomorrow note pick up dry cleaning priority urgent").date == "tomorrow")
        }

        @Test("does not parse keywords found inside note text")
        func noKeywordsInNote() {
            #expect(parseOptions("tomorrow note pick up dry cleaning priority urgent").priority == "")
        }
    }

    @Suite("multiple fields")
    struct MultipleFields {
        let input = "friday repeat weekly priority high url https://example.com note check the dashboard"

        @Test("captures date")
        func capturesDate() {
            #expect(parseOptions(input).date == "friday")
        }

        @Test("captures recurrence")
        func capturesRecurrence() {
            #expect(parseOptions(input).recurrence == "weekly")
        }

        @Test("captures priority")
        func capturesPriority() {
            #expect(parseOptions(input).priority == "high")
        }

        @Test("captures url")
        func capturesURL() {
            #expect(parseOptions(input).url == "https://example.com")
        }

        @Test("captures note")
        func capturesNote() {
            #expect(parseOptions(input).note == "check the dashboard")
        }
    }

    @Suite("fields without date")
    struct FieldsWithoutDate {
        let input = "repeat daily priority low note take with food"

        @Test("leaves date empty when string starts with keyword")
        func dateEmpty() {
            #expect(parseOptions(input).date == "")
        }

        @Test("captures recurrence when no date present")
        func capturesRecurrence() {
            #expect(parseOptions(input).recurrence == "daily")
        }

        @Test("captures priority when no date present")
        func capturesPriority() {
            #expect(parseOptions(input).priority == "low")
        }

        @Test("captures note when no date present")
        func capturesNote() {
            #expect(parseOptions(input).note == "take with food")
        }
    }

    @Suite("due keyword prefix stripped")
    struct DueKeywordPrefixStripped {
        @Test("strips 'due' prefix from weekday+time")
        func stripsFromWeekdayTime() {
            #expect(parseOptions("due friday at 9am repeat weekly").date == "friday at 9am")
        }

        @Test("preserves recurrence after stripping 'due' prefix")
        func preservesRecurrence() {
            #expect(parseOptions("due friday at 9am repeat weekly").recurrence == "weekly")
        }

        @Test("strips 'due' prefix from ISO date")
        func stripsFromISO() {
            #expect(parseOptions("due 2026-03-20 at 9am").date == "2026-03-20 at 9am")
        }

        @Test("strips 'due' prefix from bare weekday")
        func stripsFromBareWeekday() {
            #expect(parseOptions("due friday").date == "friday")
        }

        @Test("preserves 'due none' as the string 'none'")
        func preservesDueNone() {
            #expect(parseOptions("due none").date == "none")
        }

        @Test("leaves date unchanged when no 'due' prefix present")
        func unchangedWithoutDuePrefix() {
            #expect(parseOptions("friday at 9am repeat weekly").date == "friday at 9am")
        }

        @Test("strips 'date' prefix from weekday")
        func stripsDatePrefixWeekday() {
            #expect(parseOptions("date wednesday").date == "wednesday")
        }

        @Test("strips 'date' prefix from ISO date")
        func stripsDatePrefixISO() {
            #expect(parseOptions("date 2026-03-18").date == "2026-03-18")
        }
    }

    @Suite("list keyword")
    struct ListKeyword {
        @Test("captures list name")
        func capturesListName() {
            #expect(parseOptions("list Ibotta").list == "Ibotta")
        }

        @Test("leaves date empty when only list present")
        func dateEmptyWithOnlyList() {
            #expect(parseOptions("list Ibotta").date == "")
        }

        @Test("captures date before list keyword")
        func capturesDateBeforeList() {
            #expect(parseOptions("friday list Ibotta").date == "friday")
        }

        @Test("captures list name after date")
        func capturesListAfterDate() {
            #expect(parseOptions("friday list Ibotta").list == "Ibotta")
        }

        @Test("captures multi-word list name")
        func capturesMultiWordListName() {
            #expect(parseOptions("list My Work Tasks repeat weekly").list == "My Work Tasks")
        }

        @Test("captures repeat keyword after multi-word list name")
        func capturesRepeatAfterMultiWordList() {
            #expect(parseOptions("list My Work Tasks repeat weekly").recurrence == "weekly")
        }

        @Test("captures all fields when list is among them")
        func capturesAllFieldsWithList() {
            let o = parseOptions("friday repeat weekly list Ibotta priority high")
            #expect(o.date == "friday")
            #expect(o.recurrence == "weekly")
            #expect(o.list == "Ibotta")
            #expect(o.priority == "high")
        }
    }

    @Suite("splitListAndOptions")
    struct SplitListAndOptions {
        static let titles = ["Reminders", "Work Tasks", "Shopping"]

        @Suite("no args")
        struct NoArgs {
            @Test("returns nil list and empty options string")
            func nilListEmptyOptions() {
                let (list, opts) = splitListAndOptions(from: [], calendarTitles: SplitListAndOptions.titles)
                #expect(list == nil)
                #expect(opts == "")
            }
        }

        @Suite("first arg matches a calendar title")
        struct FirstArgMatches {
            @Test("returns that title as the list")
            func returnsTitleAsList() {
                let (list, _) = splitListAndOptions(from: ["Work Tasks", "friday"], calendarTitles: SplitListAndOptions.titles)
                #expect(list == "Work Tasks")
            }

            @Test("joins the remaining args as the options string")
            func joinsRemainingArgs() {
                let (_, opts) = splitListAndOptions(
                    from: ["Work Tasks", "friday", "repeat weekly"],
                    calendarTitles: SplitListAndOptions.titles
                )
                #expect(opts == "friday repeat weekly")
            }

            @Test("returns empty options string when no args follow the list name")
            func emptyOptionsWhenNoTrailingArgs() {
                let (_, opts) = splitListAndOptions(from: ["Shopping"], calendarTitles: SplitListAndOptions.titles)
                #expect(opts == "")
            }
        }

        @Suite("first arg does not match any calendar title")
        struct FirstArgDoesNotMatch {
            @Test("returns nil list")
            func returnsNilList() {
                let (list, _) = splitListAndOptions(from: ["friday", "repeat weekly"], calendarTitles: SplitListAndOptions.titles)
                #expect(list == nil)
            }

            @Test("joins all args as the options string")
            func joinsAllArgs() {
                let (_, opts) = splitListAndOptions(from: ["friday", "repeat weekly"], calendarTitles: SplitListAndOptions.titles)
                #expect(opts == "friday repeat weekly")
            }
        }
    }

    @Suite("keyword order independence")
    struct KeywordOrderIndependence {
        @Test("captures priority when it appears before repeat")
        func priorityBeforeRepeat() {
            #expect(parseOptions("priority high repeat weekly").priority == "high")
        }

        @Test("captures recurrence when priority appears before it")
        func recurrenceWhenPriorityFirst() {
            #expect(parseOptions("priority high repeat weekly").recurrence == "weekly")
        }

        @Test("captures url when it appears before priority")
        func urlBeforePriority() {
            #expect(parseOptions("url https://example.com priority medium").url == "https://example.com")
        }

        @Test("captures priority when url appears before it")
        func priorityWhenURLFirst() {
            #expect(parseOptions("url https://example.com priority medium").priority == "medium")
        }
    }
}
