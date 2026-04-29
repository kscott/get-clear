import Quick
import Nimble
import Foundation
import CalendarLib

final class CalendarWhatHandlerSpec: QuickSpec {
    override class func spec() {

        describe("handleWhat") {
            it("throws for an unrecognised range string") {
                expect { try handleWhat(args: ["what", "notarange"]) }.to(throwError())
            }
            it("returns a non-empty string for today") {
                let out = try handleWhat(args: ["what"])
                expect(out).toNot(beEmpty())
            }
            it("returns a non-empty string for a named range") {
                let out = try handleWhat(args: ["what", "7d"])
                expect(out).toNot(beEmpty())
            }
        }
    }
}
