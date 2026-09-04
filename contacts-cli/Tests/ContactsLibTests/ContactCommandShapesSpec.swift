// ContactCommandShapesSpec.swift
//
// Tests for ContactCommandShapes — each shape parses its documented forms and
// rejects the malformed ones. `change` has no shape (see ContactCommandShapes.swift)
// and is exercised via ContactChangeParsingSpec instead.

import ContactsLib
import GetClearKit
import Testing

@Suite("ContactCommandShapes")
struct ContactCommandShapesTests {
    @Suite("add")
    struct Add {
        @Test("parses a name alone")
        func parsesNameAlone() throws {
            let parsed = try parseCommand(["Alice"], shape: ContactCommandShapes.add)
            #expect(parsed.identifiers == ["Alice"])
        }

        @Test("parses a name with email, phone, and company")
        func parsesNameWithFields() throws {
            let parsed = try parseCommand(
                ["Alice", "email", "a@x.com", "phone", "555-1234", "company", "Acme"],
                shape: ContactCommandShapes.add
            )
            #expect(parsed.values == ["email": "a@x.com", "phone": "555-1234", "company": "Acme"])
        }

        @Test("parses a name with 'to' a group")
        func parsesNameWithTo() throws {
            let parsed = try parseCommand(["Alice", "to", "Friends"], shape: ContactCommandShapes.add)
            #expect(parsed.values["to"] == "Friends")
        }

        @Test("a second occurrence of a keyword throws duplicateKeyword")
        func duplicateKeywordThrows() {
            #expect(throws: ArgumentError.duplicateKeyword("email")) {
                try parseCommand(["Alice", "email", "a@x.com", "email", "b@x.com"], shape: ContactCommandShapes.add)
            }
        }

        @Test("no name throws missingIdentifier")
        func noNameThrows() {
            #expect(throws: ArgumentError.missingIdentifier(name: "name")) {
                try parseCommand([], shape: ContactCommandShapes.add)
            }
        }
    }

    @Suite("rename")
    struct Rename {
        @Test("parses a name and a new name")
        func parsesBothNames() throws {
            let parsed = try parseCommand(["Alice", "Alice Jones"], shape: ContactCommandShapes.rename)
            #expect(parsed.identifiers == ["Alice", "Alice Jones"])
        }

        @Test("an unquoted multi-word new name throws unexpectedTokens")
        func unquotedNewNameThrows() {
            #expect(throws: ArgumentError.unexpectedTokens(["Jones"])) {
                try parseCommand(["Alice", "Alice", "Jones"], shape: ContactCommandShapes.rename)
            }
        }

        @Test("only one name throws missingIdentifier for the new name")
        func onlyOneNameThrows() {
            #expect(throws: ArgumentError.missingIdentifier(name: "new name")) {
                try parseCommand(["Alice"], shape: ContactCommandShapes.rename)
            }
        }
    }

    @Suite("remove")
    struct Remove {
        @Test("parses a name alone")
        func parsesNameAlone() throws {
            let parsed = try parseCommand(["Alice"], shape: ContactCommandShapes.remove)
            #expect(parsed.identifiers == ["Alice"] && parsed.values["from"] == nil)
        }

        @Test("parses a name with 'from' a group")
        func parsesNameWithFrom() throws {
            let parsed = try parseCommand(["Alice", "from", "Friends"], shape: ContactCommandShapes.remove)
            #expect(parsed.values["from"] == "Friends")
        }
    }

    @Suite("find / show / list")
    struct FindShowList {
        @Test("find parses a quoted multi-word query")
        func findParsesQuotedQuery() throws {
            let parsed = try parseCommand(["Alice Smith"], shape: ContactCommandShapes.find)
            #expect(parsed.identifiers == ["Alice Smith"])
        }

        @Test("find with no query throws missingIdentifier")
        func findNoQueryThrows() {
            #expect(throws: ArgumentError.missingIdentifier(name: "query")) {
                try parseCommand([], shape: ContactCommandShapes.find)
            }
        }

        @Test("show parses a name")
        func showParsesName() throws {
            let parsed = try parseCommand(["Alice"], shape: ContactCommandShapes.show)
            #expect(parsed.identifiers == ["Alice"])
        }

        @Test("list parses a group")
        func listParsesGroup() throws {
            let parsed = try parseCommand(["Friends"], shape: ContactCommandShapes.list)
            #expect(parsed.identifiers == ["Friends"])
        }

        @Test("an unquoted multi-word group throws unexpectedTokens")
        func unquotedGroupThrows() {
            #expect(throws: ArgumentError.unexpectedTokens(["Members"])) {
                try parseCommand(["Team", "Members"], shape: ContactCommandShapes.list)
            }
        }
    }

    @Suite("lists / open")
    struct NullaryCommands {
        static let allNullaryShapes: [(String, CommandShape)] = [
            ("lists", ContactCommandShapes.lists),
            ("open", ContactCommandShapes.open)
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
}
