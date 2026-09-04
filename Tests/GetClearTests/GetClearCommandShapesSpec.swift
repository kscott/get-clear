// GetClearCommandShapesSpec.swift
//
// Tests for GetClearCommandShapes — each shape parses its documented forms and
// rejects the malformed ones.

@testable import GetClear
import GetClearKit
import Testing

@Suite("GetClearCommandShapes")
struct GetClearCommandShapesTests {
    @Suite("recap")
    struct Recap {
        @Test("parses a bare range")
        func parsesBareRange() throws {
            let parsed = try parseCommand(["7d"], shape: GetClearCommandShapes.recap)
            #expect(parsed.bareDateRange == "7d")
        }

        @Test("parses a multi-word range")
        func parsesMultiWordRange() throws {
            let parsed = try parseCommand(["march", "15", "to", "march", "20"], shape: GetClearCommandShapes.recap)
            #expect(parsed.bareDateRange == "march 15 to march 20")
        }

        @Test("no range parses with a nil bareDateRange, not an error")
        func noRangeParsesWithNilBareDateRange() throws {
            let parsed = try parseCommand([], shape: GetClearCommandShapes.recap)
            #expect(parsed.bareDateRange == nil)
        }
    }

    @Suite("setup / update / check-update")
    struct NullaryCommands {
        static let allNullaryShapes: [(String, CommandShape)] = [
            ("setup", GetClearCommandShapes.setup),
            ("update", GetClearCommandShapes.update),
            ("check-update", GetClearCommandShapes.checkUpdate)
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
