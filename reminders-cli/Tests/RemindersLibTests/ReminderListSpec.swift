import Quick
import Nimble
@testable import RemindersLib

final class ReminderListSpec: QuickSpec {
    override class func spec() {
        describe("matches(identifier:title:)") {
            context("when list has no identifier") {
                let list = ReminderList(title: "Personal")

                it("matches by title") {
                    expect(list.matches(identifier: "some-id", title: "Personal")) == true
                }
                it("does not match a different title") {
                    expect(list.matches(identifier: "some-id", title: "Work")) == false
                }
            }

            context("when list has an identifier") {
                let list = ReminderList(identifier: "abc-123", title: "Personal")

                it("matches by identifier") {
                    expect(list.matches(identifier: "abc-123", title: "anything")) == true
                }
                it("does not match a different identifier") {
                    expect(list.matches(identifier: "xyz-999", title: "Personal")) == false
                }
            }
        }
    }
}
