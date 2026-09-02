@testable import RemindersLib
import Testing

@Suite("matches(identifier:title:)")
struct ReminderListTests {
    @Suite("when list has no identifier")
    struct NoIdentifier {
        let list = ReminderList(title: "Personal")

        @Test("matches by title")
        func matchesByTitle() {
            #expect(list.matches(identifier: "some-id", title: "Personal"))
        }

        @Test("does not match a different title")
        func noMatchDifferentTitle() {
            #expect(!list.matches(identifier: "some-id", title: "Work"))
        }
    }

    @Suite("when list has an identifier")
    struct HasIdentifier {
        let list = ReminderList(identifier: "abc-123", title: "Personal")

        @Test("matches by identifier")
        func matchesByIdentifier() {
            #expect(list.matches(identifier: "abc-123", title: "anything"))
        }

        @Test("does not match a different identifier")
        func noMatchDifferentIdentifier() {
            #expect(!list.matches(identifier: "xyz-999", title: "Personal"))
        }
    }
}
