import GetClearKit
import Nimble
import Quick

final class ValueChangeSpec: QuickSpec {
    override class func spec() {
        describe("ValueChange") {
            it("unchanged is equal to unchanged") {
                expect(ValueChange<String>.unchanged) == .unchanged
            }
            it("cleared is equal to cleared") {
                expect(ValueChange<String>.cleared) == .cleared
            }
            it("added carries its value") {
                expect(ValueChange.added("a")) == .added("a")
            }
            it("removed carries its value") {
                expect(ValueChange.removed("a")) == .removed("a")
            }
            it("replaced carries from and to") {
                expect(ValueChange.replaced(from: "a", to: "b")) == .replaced(from: "a", to: "b")
            }
            it("distinct cases are not equal") {
                expect(ValueChange<String>.unchanged) != .cleared
            }
        }
    }
}
