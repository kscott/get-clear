// WhatHandlerSpec.swift
// Tests for MailLib handleWhat.

import Foundation
import MailLib
import Nimble
import Quick

final class MailWhatHandlerSpec: QuickSpec {
    override class func spec() {
        describe("handleWhat") {
            it("returns output for the default range") {
                expect { try handleWhat(args: ["what"]) }.notTo(throwError())
            }
            it("returns output for a named range") {
                expect { try handleWhat(args: ["what", "today"]) }.notTo(throwError())
            }
            it("returns output for a non-today named range") {
                expect { try handleWhat(args: ["what", "yesterday"]) }.notTo(throwError())
            }
            it("throws for an unrecognised range") {
                expect { try handleWhat(args: ["what", "notarange"]) }.to(throwError())
            }
        }
    }
}
