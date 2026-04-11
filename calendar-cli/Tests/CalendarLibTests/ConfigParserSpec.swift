// ConfigParserSpec.swift
//
// Tests for CalendarLib ConfigParser — TOML config parsing into CalendarConfig.

import Quick
import Nimble
import Foundation
import CalendarLib

final class ConfigParserSpec: QuickSpec {
    override class func spec() {
        describe("parseConfig") {
            context("empty or missing config") {
                it("returns no subsets for empty content") {
                    expect(parseConfig("").subsets).to(beEmpty())
                }
            }

            context("basic subsets") {
                let toml = """
                [subsets]
                work     = ["Work", "Meetings"]
                personal = ["Home", "Family", "Birthdays & Anniversaries"]
                """

                it("parses the work subset") {
                    expect(parseConfig(toml).subsets["work"]).toNot(beNil())
                }
                it("work subset has 2 calendars") {
                    expect(parseConfig(toml).subsets["work"]?.count) == 2
                }
                it("work subset includes Work") {
                    expect(parseConfig(toml).subsets["work"]).to(contain("Work"))
                }
                it("work subset includes Meetings") {
                    expect(parseConfig(toml).subsets["work"]).to(contain("Meetings"))
                }
                it("personal subset has 3 calendars") {
                    expect(parseConfig(toml).subsets["personal"]?.count) == 3
                }
                it("personal subset includes calendar names with special characters") {
                    expect(parseConfig(toml).subsets["personal"]).to(contain("Birthdays & Anniversaries"))
                }
            }

            context("subset key casing") {
                let toml = """
                [subsets]
                Work = ["Work"]
                """

                it("lowercases subset keys") {
                    expect(parseConfig(toml).subsets["work"]).toNot(beNil())
                }
                it("does not store the original-case key") {
                    expect(parseConfig(toml).subsets["Work"]).to(beNil())
                }
            }

            context("non-subsets sections") {
                let toml = """
                [other]
                foo = ["bar"]

                [subsets]
                personal = ["Home"]
                """

                it("ignores sections other than [subsets]") {
                    expect(parseConfig(toml).subsets.count) == 1
                }
                it("parses the subsets section correctly") {
                    expect(parseConfig(toml).subsets["personal"]).toNot(beNil())
                }
                it("does not parse keys from other sections") {
                    expect(parseConfig(toml).subsets["foo"]).to(beNil())
                }
            }

            context("comments and blank lines") {
                let toml = """
                # This is a comment

                [subsets]
                # another comment
                work = ["Work"]
                """

                it("ignores comments and blank lines") {
                    expect(parseConfig(toml).subsets["work"]).toNot(beNil())
                }
            }
        }
    }
}
