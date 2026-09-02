// ReminderCommandShapesSpec.swift
//
// Tests for ReminderCommandShapes — each shape parses its documented forms and
// rejects the malformed ones. See contracts/reminders-shapes.md for the source examples.

import GetClearKit
import RemindersLib
import Testing

@Suite("ReminderCommandShapes")
struct ReminderCommandShapesTests {
    @Suite("add")
    struct Add {
        @Test("parses a title with a list, repeat, and priority")
        func parsesCanonicalForm() throws {
            let parsed = try parseCommand(
                ["Pay rent", "march 1", "list", "Bills", "repeat", "monthly", "priority", "high"],
                shape: ReminderCommandShapes.add
            )
            #expect(parsed.identifiers == ["Pay rent"] && parsed.bareDate == "march 1")
        }

        @Test("a reordered-keyword variant parses identically")
        func reorderedKeywordsParseIdentically() throws {
            let a = try parseCommand(
                ["Pay rent", "list", "Bills", "priority", "high"], shape: ReminderCommandShapes.add
            )
            let b = try parseCommand(
                ["Pay rent", "priority", "high", "list", "Bills"], shape: ReminderCommandShapes.add
            )
            #expect(a == b)
        }

        @Test("a duplicate keyword throws duplicateKeyword")
        func duplicateKeywordThrows() {
            #expect(throws: ArgumentError.duplicateKeyword("list")) {
                try parseCommand(["Pay rent", "list", "A", "list", "B"], shape: ReminderCommandShapes.add)
            }
        }

        @Test("a bare keyword word where the title belongs throws missingIdentifier")
        func bareKeywordWordAsTitleThrows() {
            #expect(throws: ArgumentError.missingIdentifier(name: "title", blockedBy: "list")) {
                try parseCommand(["list"], shape: ReminderCommandShapes.add)
            }
        }

        @Test("a stray phrase in the leading region lands in bareDate, not an error")
        func strayPhraseLandsInBareDate() throws {
            let parsed = try parseCommand(["Pay rent", "Bills", "march", "1"], shape: ReminderCommandShapes.add)
            #expect(parsed.bareDate == "Bills march 1")
        }

        @Test("note captures to end of line, quoted or not")
        func noteCapturesToEnd() throws {
            let parsed = try parseCommand(
                ["Call dentist", "friday", "note", "ask", "about", "the", "crown"], shape: ReminderCommandShapes.add
            )
            #expect(parsed.trailingText == "ask about the crown")
        }
    }

    @Suite("change")
    struct Change {
        @Test("priority and due none both parse onto the same command")
        func priorityAndDueNoneBothParse() throws {
            let parsed = try parseCommand(
                ["Pay rent", "priority", "high", "due", "none"], shape: ReminderCommandShapes.change
            )
            #expect(parsed.values["priority"] == "high" && parsed.values["due"] == "none")
        }

        @Test("a bare date and the due keyword together throw dateGivenTwice")
        func bareDateAndDueThrowsDateGivenTwice() {
            #expect(throws: ArgumentError.dateGivenTwice) {
                try parseCommand(["Pay rent", "march", "1", "due", "none"], shape: ReminderCommandShapes.change)
            }
        }
    }

    @Suite("rename")
    struct Rename {
        @Test("parses two quoted identifiers")
        func parsesTwoIdentifiers() throws {
            let parsed = try parseCommand(["Pay rent", "Pay mortgage"], shape: ReminderCommandShapes.rename)
            #expect(parsed.identifiers == ["Pay rent", "Pay mortgage"])
        }

        @Test("a reordered list keyword parses identically")
        func reorderedListParsesIdentically() throws {
            let parsed = try parseCommand(
                ["Pay rent", "Pay mortgage", "list", "Bills"], shape: ReminderCommandShapes.rename
            )
            #expect(parsed.values["list"] == "Bills")
        }

        @Test("a duplicate list keyword throws duplicateKeyword")
        func duplicateKeywordThrows() {
            #expect(throws: ArgumentError.duplicateKeyword("list")) {
                try parseCommand(
                    ["Pay rent", "Pay mortgage", "list", "A", "list", "B"], shape: ReminderCommandShapes.rename
                )
            }
        }

        @Test("a bare keyword word where the new title belongs throws missingIdentifier")
        func bareKeywordWordAsNewTitleThrows() {
            #expect(throws: ArgumentError.missingIdentifier(name: "new title", blockedBy: "list")) {
                try parseCommand(["Buy milk", "list"], shape: ReminderCommandShapes.rename)
            }
        }

        @Test("a stray word after both identifiers throws unexpectedTokens")
        func strayWordThrowsUnexpectedTokens() {
            #expect(throws: ArgumentError.unexpectedTokens(["Bills"])) {
                try parseCommand(["Pay rent", "Pay mortgage", "Bills"], shape: ReminderCommandShapes.rename)
            }
        }
    }

    @Suite("remove / done / show")
    struct RemoveDoneShow {
        @Test("remove parses a title with a list keyword")
        func removeParsesWithList() throws {
            let parsed = try parseCommand(["Pay rent", "list", "Household Bills"], shape: ReminderCommandShapes.remove)
            #expect(parsed.identifiers == ["Pay rent"] && parsed.values["list"] == "Household Bills")
        }

        @Test("done parses a reordered list keyword identically")
        func doneReorderedParsesIdentically() throws {
            let parsed = try parseCommand(["Buy milk", "list", "Bills"], shape: ReminderCommandShapes.done)
            #expect(parsed.values["list"] == "Bills")
        }

        @Test("show a duplicate list keyword throws duplicateKeyword")
        func showDuplicateKeywordThrows() {
            #expect(throws: ArgumentError.duplicateKeyword("list")) {
                try parseCommand(["Buy milk", "list", "A", "list", "B"], shape: ReminderCommandShapes.show)
            }
        }

        @Test("remove a bare keyword word where the title belongs throws missingIdentifier")
        func removeBareKeywordWordAsTitleThrows() {
            #expect(throws: ArgumentError.missingIdentifier(name: "title", blockedBy: "list")) {
                try parseCommand(["list"], shape: ReminderCommandShapes.remove)
            }
        }

        @Test("done a stray word after the title throws unexpectedTokens")
        func doneStrayWordThrowsUnexpectedTokens() {
            #expect(throws: ArgumentError.unexpectedTokens(["Bills"])) {
                try parseCommand(["Pay rent", "Bills"], shape: ReminderCommandShapes.done)
            }
        }
    }

    @Suite("shape self-validation")
    struct ShapeSelfValidation {
        static let allShapes: [(String, CommandShape)] = [
            ("add", ReminderCommandShapes.add),
            ("change", ReminderCommandShapes.change),
            ("rename", ReminderCommandShapes.rename),
            ("remove", ReminderCommandShapes.remove),
            ("done", ReminderCommandShapes.done),
            ("show", ReminderCommandShapes.show)
        ]

        @Test("every keyword canonical is unique across canonicals and aliases", arguments: allShapes)
        func canonicalsAreUnique(name: String, shape: CommandShape) {
            var seen = Set<String>()
            for keyword in shape.keywords {
                seen.insert(keyword.canonical.lowercased())
                for alias in keyword.aliases {
                    seen.insert(alias.lowercased())
                }
            }
            let total = shape.keywords.count + shape.keywords.reduce(0) { $0 + $1.aliases.count }
            #expect(seen.count == total)
        }

        @Test("at most one identifier is optional, and it is last", arguments: allShapes)
        func atMostOneOptionalIdentifierAndItIsLast(name: String, shape: CommandShape) {
            let optionalCount = shape.identifiers.filter { !$0.required }.count
            #expect(optionalCount <= 1)
            if optionalCount == 1 {
                #expect(shape.identifiers.last?.required == false)
            }
        }

        @Test("trailingTextKeyword is never also a regular keyword", arguments: allShapes)
        func trailingTextKeywordNotInKeywords(name: String, shape: CommandShape) {
            guard let trailing = shape.trailingTextKeyword else { return }
            let allWords = shape.keywords.flatMap { [$0.canonical] + $0.aliases }.map { $0.lowercased() }
            #expect(!allWords.contains(trailing.lowercased()))
        }
    }
}
