// ListHandlerSpec.swift

import Foundation
import GetClearKit
import Nimble
import Quick
import RemindersLib

final class ListHandlerSpec: AsyncSpec {
    override class func spec() {
        var store: SpyStore!

        beforeEach { store = SpyStore() }

        describe("handleList") {
            it("returns grouped rows when no list filter is given") {
                store.lists = [personalList, workList]
                store.items = [makeItem(), makeItem(title: "Team standup", list: workList)]
                let out = try await handleList(args: ["list"], store: store)
                expect(out).to(contain("Personal"))
                expect(out).to(contain("Work"))
            }
            it("returns ungrouped rows when a list filter matches") {
                store.lists = [personalList]
                store.items = [makeItem()]
                let out = try await handleList(args: ["list", "Personal"], store: store)
                expect(out).to(contain("Pay rent"))
                expect(out).notTo(contain("\nPersonal"))
            }
            it("applies the sort order when 'by' is specified") {
                store.lists = [personalList]
                store.items = [makeItem()]
                let out = try await handleList(args: ["list", "by", "title"], store: store)
                expect(out).to(contain("Pay rent"))
            }
            it("throws when the named list does not exist") {
                store.lists = [personalList]
                await expect {
                    try await handleList(args: ["list", "Nonexistent"], store: store)
                }.to(throwError { (e: ReminderHandlerError) in
                    expect(e.message).to(contain("Nonexistent"))
                })
            }
        }
    }
}
