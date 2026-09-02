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
}
