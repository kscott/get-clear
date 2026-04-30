import ContactsLib
import Nimble
import Quick

final class UsageTextSpec: QuickSpec {
    override class func spec() {
        describe("usageText") {
            it("contains the list command") {
                expect(usageText(identity: "contacts")).to(contain("contacts list"))
            }
            it("contains the find command") {
                expect(usageText(identity: "contacts")).to(contain("contacts find"))
            }
            it("contains the add command") {
                expect(usageText(identity: "contacts")).to(contain("contacts add"))
            }
            it("contains the feedback URL") {
                expect(usageText(identity: "contacts")).to(contain("github.com/kscott/get-clear/issues"))
            }
            it("does not contain the removed export command") {
                expect(usageText(identity: "contacts")).toNot(contain("export"))
            }
        }
    }
}
