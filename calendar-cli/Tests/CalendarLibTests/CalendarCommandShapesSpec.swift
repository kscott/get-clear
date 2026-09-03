// CalendarCommandShapesSpec.swift
//
// Tests for CalendarCommandShapes — each shape parses its documented forms and
// rejects the malformed ones.

import CalendarLib
import GetClearKit
import Testing

@Suite("CalendarCommandShapes")
struct CalendarCommandShapesTests {
    @Suite("add")
    struct Add {
        @Test("parses a title with a trailing date/time phrase")
        func parsesTitleAndDateTime() throws {
            let parsed = try parseCommand(
                ["Sprint Planning", "tomorrow", "10am"], shape: CalendarCommandShapes.add
            )
            #expect(parsed.identifiers == ["Sprint Planning"] && parsed.bareDateRange == "tomorrow 10am")
        }

        @Test("parses a title alone, with no date/time phrase")
        func parsesTitleAlone() throws {
            let parsed = try parseCommand(["Quick Check"], shape: CalendarCommandShapes.add)
            #expect(parsed.identifiers == ["Quick Check"] && parsed.bareDateRange == nil)
        }

        @Test("a bare keyword-shaped word alone is not blocked, since add has no keywords")
        func noKeywordsToBlockOn() throws {
            let parsed = try parseCommand(["Meeting"], shape: CalendarCommandShapes.add)
            #expect(parsed.identifiers == ["Meeting"])
        }

        @Test("no title throws missingIdentifier")
        func noTitleThrows() {
            #expect(throws: ArgumentError.missingIdentifier(name: "title")) {
                try parseCommand([], shape: CalendarCommandShapes.add)
            }
        }
    }

    @Suite("find")
    struct Find {
        @Test("parses a quoted multi-word query with no range")
        func parsesQuotedQuery() throws {
            let parsed = try parseCommand(["Lunch with Alice"], shape: CalendarCommandShapes.find)
            #expect(parsed.identifiers == ["Lunch with Alice"] && parsed.bareDateRange == nil)
        }

        @Test("parses a single-word query with a trailing range")
        func parsesQueryAndRange() throws {
            let parsed = try parseCommand(["dentist", "next", "week"], shape: CalendarCommandShapes.find)
            #expect(parsed.identifiers == ["dentist"] && parsed.bareDateRange == "next week")
        }

        @Test("no query throws missingIdentifier")
        func noQueryThrows() {
            #expect(throws: ArgumentError.missingIdentifier(name: "query")) {
                try parseCommand([], shape: CalendarCommandShapes.find)
            }
        }
    }

    @Suite("show / remove")
    struct ShowRemove {
        @Test("show parses a title with a trailing range")
        func showParsesTitleAndRange() throws {
            let parsed = try parseCommand(["Board Meeting", "30d"], shape: CalendarCommandShapes.show)
            #expect(parsed.identifiers == ["Board Meeting"] && parsed.bareDateRange == "30d")
        }

        @Test("remove parses a title alone")
        func removeParsesTitleAlone() throws {
            let parsed = try parseCommand(["Old Meeting"], shape: CalendarCommandShapes.remove)
            #expect(parsed.identifiers == ["Old Meeting"] && parsed.bareDateRange == nil)
        }

        @Test("show no title throws missingIdentifier")
        func showNoTitleThrows() {
            #expect(throws: ArgumentError.missingIdentifier(name: "title")) {
                try parseCommand([], shape: CalendarCommandShapes.show)
            }
        }
    }

    @Suite("list")
    struct List {
        @Test("parses a bare range")
        func parsesBareRange() throws {
            let parsed = try parseCommand(["7d"], shape: CalendarCommandShapes.list)
            #expect(parsed.bareDateRange == "7d")
        }

        @Test("parses a multi-word range")
        func parsesMultiWordRange() throws {
            let parsed = try parseCommand(["march", "15", "to", "march", "20"], shape: CalendarCommandShapes.list)
            #expect(parsed.bareDateRange == "march 15 to march 20")
        }

        @Test("no range parses with a nil bareDateRange, not an error")
        func noRangeParsesWithNilBareDateRange() throws {
            let parsed = try parseCommand([], shape: CalendarCommandShapes.list)
            #expect(parsed.bareDateRange == nil)
        }
    }

    @Suite("next")
    struct Next {
        @Test("parses with no count")
        func parsesWithNoCount() throws {
            let parsed = try parseCommand([], shape: CalendarCommandShapes.next)
            #expect(parsed.identifiers.isEmpty)
        }

        @Test("parses a count")
        func parsesCount() throws {
            let parsed = try parseCommand(["3"], shape: CalendarCommandShapes.next)
            #expect(parsed.identifiers == ["3"])
        }
    }

    @Suite("today / week / calendars / setup / open")
    struct NullaryCommands {
        static let allNullaryShapes: [(String, CommandShape)] = [
            ("today", CalendarCommandShapes.today),
            ("week", CalendarCommandShapes.week),
            ("calendars", CalendarCommandShapes.calendars),
            ("setup", CalendarCommandShapes.setup),
            ("open", CalendarCommandShapes.open)
        ]

        @Test("parses with no arguments", arguments: allNullaryShapes)
        func parsesBare(name: String, shape: CommandShape) throws {
            let parsed = try parseCommand([], shape: shape)
            #expect(parsed.identifiers.isEmpty)
        }

        @Test("a stray token throws unexpectedTokens", arguments: allNullaryShapes)
        func strayTokenThrows(name: String, shape: CommandShape) {
            #expect(throws: ArgumentError.unexpectedTokens(["extra"])) {
                try parseCommand(["extra"], shape: shape)
            }
        }
    }

    @Suite("shape self-validation")
    struct ShapeSelfValidation {
        static let allShapes: [(String, CommandShape)] = [
            ("add", CalendarCommandShapes.add),
            ("find", CalendarCommandShapes.find),
            ("show", CalendarCommandShapes.show),
            ("remove", CalendarCommandShapes.remove),
            ("list", CalendarCommandShapes.list),
            ("next", CalendarCommandShapes.next),
            ("today", CalendarCommandShapes.today),
            ("week", CalendarCommandShapes.week),
            ("calendars", CalendarCommandShapes.calendars),
            ("setup", CalendarCommandShapes.setup),
            ("open", CalendarCommandShapes.open)
        ]

        @Test("at most one identifier is optional, and it is last", arguments: allShapes)
        func atMostOneOptionalIdentifierAndItIsLast(name: String, shape: CommandShape) {
            let optionalCount = shape.identifiers.filter { !$0.required }.count
            #expect(optionalCount <= 1)
            if optionalCount == 1 {
                #expect(shape.identifiers.last?.required == false)
            }
        }

        @Test("no shape declares keywords yet — calendar adds none in this migration", arguments: allShapes)
        func noKeywordsDeclared(name: String, shape: CommandShape) {
            #expect(shape.keywords.isEmpty)
        }
    }
}
