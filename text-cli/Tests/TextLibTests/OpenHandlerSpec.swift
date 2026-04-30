// OpenHandlerSpec.swift
// Tests for TextLib handleOpen.

import Foundation
import Nimble
import Quick
import TextLib

final class OpenHandlerSpec: QuickSpec {
    override class func spec() {
        describe("handleOpen") {
            it("opens the Messages app URL") {
                var opened: URL?
                handleOpen(opener: { opened = $0 })
                expect(opened?.path) == "/System/Applications/Messages.app"
            }
        }
    }
}
