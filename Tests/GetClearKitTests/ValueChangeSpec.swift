import Foundation
import GetClearKit
import Testing

@Suite("ValueChange")
struct ValueChangeTests {
    @Test("unchanged is equal to unchanged")
    func unchangedEqualsUnchanged() {
        #expect(ValueChange<String>.unchanged == .unchanged)
    }

    @Test("cleared is equal to cleared")
    func clearedEqualsCleared() {
        #expect(ValueChange<String>.cleared == .cleared)
    }

    @Test("added carries its value")
    func addedCarriesValue() {
        #expect(ValueChange.added("a") == .added("a"))
    }

    @Test("removed carries its value")
    func removedCarriesValue() {
        #expect(ValueChange.removed("a") == .removed("a"))
    }

    @Test("replaced carries from and to")
    func replacedCarriesFromAndTo() {
        #expect(ValueChange.replaced(from: "a", to: "b") == .replaced(from: "a", to: "b"))
    }

    @Test("distinct cases are not equal")
    func distinctCasesNotEqual() {
        #expect(ValueChange<String>.unchanged != .cleared)
    }

    @Suite("coding")
    struct Coding {
        private func roundTrip(_ change: ValueChange<String>) throws -> ValueChange<String> {
            try JSONDecoder().decode(ValueChange<String>.self, from: JSONEncoder().encode(change))
        }

        @Test("unchanged survives a JSON round trip")
        func unchanged() throws {
            #expect(try roundTrip(.unchanged) == .unchanged)
        }

        @Test("cleared survives a JSON round trip")
        func cleared() throws {
            #expect(try roundTrip(.cleared) == .cleared)
        }

        @Test("added keeps its value through a JSON round trip")
        func added() throws {
            #expect(try roundTrip(.added("a")) == .added("a"))
        }

        @Test("removed keeps its value through a JSON round trip")
        func removed() throws {
            #expect(try roundTrip(.removed("a")) == .removed("a"))
        }

        @Test("replaced keeps from and to through a JSON round trip")
        func replaced() throws {
            #expect(try roundTrip(.replaced(from: "a", to: "b")) == .replaced(from: "a", to: "b"))
        }
    }
}
