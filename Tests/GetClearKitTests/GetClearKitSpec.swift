// GetClearKitSpec.swift
//
// Tests for GetClearKit utilities — TimespanFormatter, UpdateChecker, parseArgs.

import Quick
import Nimble
import Foundation
import GetClearKit

final class GetClearKitSpec: QuickSpec {
    override class func spec() {
        let cal = Calendar.current

        let makeDate = { (hour: Int, minute: Int) -> Date in
            cal.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
        }

        // MARK: - TimespanFormatter

        describe("TimespanFormatter") {
            context("15-minute rounding") {
                let rounded = { (h: Int, m: Int) -> Int in
                    cal.component(.minute, from: TimespanFormatter.roundTo15Minutes(makeDate(h, m)))
                }
                let roundedHour = { (h: Int, m: Int) -> Int in
                    cal.component(.hour, from: TimespanFormatter.roundTo15Minutes(makeDate(h, m)))
                }

                it("X:07 rounds down to X:00")  { expect(rounded(9, 7))  == 0  }
                it("X:08 rounds up to X:15")    { expect(rounded(9, 8))  == 15 }
                it("X:22 rounds down to X:15")  { expect(rounded(9, 22)) == 15 }
                it("X:23 rounds up to X:30")    { expect(rounded(9, 23)) == 30 }
                it("X:37 rounds down to X:30")  { expect(rounded(9, 37)) == 30 }
                it("X:38 rounds up to X:45")    { expect(rounded(9, 38)) == 45 }
                it("X:52 rounds down to X:45")  { expect(rounded(9, 52)) == 45 }
                it("X:53 rounds up to the next hour") {
                    expect(rounded(9, 53)) == 0
                    expect(roundedHour(9, 53)) == 10
                }
                it("X:00 stays at X:00")  { expect(rounded(9, 0))  == 0  }
                it("X:15 stays at X:15")  { expect(rounded(9, 15)) == 15 }
                it("X:30 stays at X:30")  { expect(rounded(9, 30)) == 30 }
                it("X:45 stays at X:45")  { expect(rounded(9, 45)) == 45 }
            }

            context("formatted output") {
                let start = { makeDate(9, 3)  }()  // rounds to 9:00am
                let end   = { makeDate(16, 47) }()  // rounds to 4:45pm

                it("range includes the start time") {
                    expect(TimespanFormatter.format(first: start, last: end)).to(contain("9:00"))
                }
                it("range includes the end time") {
                    expect(TimespanFormatter.format(first: start, last: end)).to(contain("4:45"))
                }
                it("range includes an arrow separator") {
                    expect(TimespanFormatter.format(first: start, last: end)).to(contain("→"))
                }
                it("single entry shows only the start time") {
                    expect(TimespanFormatter.format(first: start, last: nil)).to(contain("9:00"))
                }
                it("single entry has no arrow") {
                    expect(TimespanFormatter.format(first: start, last: nil)).toNot(contain("→"))
                }
            }

            context("timespan from entries") {
                it("returns nil for an empty entries array") {
                    expect(TimespanFormatter.timespan(from: [])).to(beNil())
                }
            }
        }

        // MARK: - UpdateChecker

        describe("UpdateChecker") {
            context("version comparison") {
                it("a newer patch version is newer") {
                    expect(UpdateChecker.isNewer("1.1.3", than: "1.1.2")) == true
                }
                it("a newer minor version is newer") {
                    expect(UpdateChecker.isNewer("1.2.0", than: "1.1.9")) == true
                }
                it("a newer major version is newer") {
                    expect(UpdateChecker.isNewer("2.0.0", than: "1.9.9")) == true
                }
                it("the same version is not newer") {
                    expect(UpdateChecker.isNewer("1.1.2", than: "1.1.2")) == false
                }
                it("an older patch version is not newer") {
                    expect(UpdateChecker.isNewer("1.1.1", than: "1.1.2")) == false
                }
                it("an older minor version is not newer") {
                    expect(UpdateChecker.isNewer("1.0.9", than: "1.1.0")) == false
                }
                it("an older major version is not newer") {
                    expect(UpdateChecker.isNewer("1.9.9", than: "2.0.0")) == false
                }
                it("strips a leading 'v' prefix") {
                    expect(UpdateChecker.isNewer("v1.1.3", than: "1.1.2")) == true
                }
                it("handles a leading 'v' on both versions") {
                    expect(UpdateChecker.isNewer("v1.1.2", than: "v1.1.2")) == false
                }
            }

            context("cache") {
                it("cachedLatest does not crash when no cache file exists") {
                    // Structural test — verifies no crash on missing file
                    let _ = UpdateChecker.cachedLatest()
                    expect(true) == true
                }
            }

            context("hint") {
                it("returns nil on a dev machine with no pkgutil receipt") {
                    expect(UpdateChecker.hint()).to(beNil())
                }
            }
        }

        // MARK: - parseArgs

        describe("parseArgs") {
            context("no arguments") {
                it("empty array produces .empty") {
                    guard case .empty = parseArgs([]) else { fail("expected .empty"); return }
                }
            }

            context("help flags") {
                it("'help' produces .help") {
                    guard case .help = parseArgs(["help"]) else { fail("expected .help"); return }
                }
                it("'--help' produces .help") {
                    guard case .help = parseArgs(["--help"]) else { fail("expected .help"); return }
                }
                it("'-h' produces .help") {
                    guard case .help = parseArgs(["-h"]) else { fail("expected .help"); return }
                }
                it("'help add' produces .help — subcommand help not yet supported") {
                    guard case .help = parseArgs(["help", "add"]) else { fail("expected .help"); return }
                }
            }

            context("version flags") {
                it("'version' produces .version") {
                    guard case .version = parseArgs(["version"]) else { fail("expected .version"); return }
                }
                it("'--version' produces .version") {
                    guard case .version = parseArgs(["--version"]) else { fail("expected .version"); return }
                }
                it("'-v' produces .version") {
                    guard case .version = parseArgs(["-v"]) else { fail("expected .version"); return }
                }
            }

            // Note: '--help', '-h', 'help', '--version', '-v', 'version' after a command call
            // fail() → exit(). These are not testable without process isolation.

            context("command dispatch") {
                it("first argument becomes the command") {
                    guard case .command(let cmd, _) = parseArgs(["list", "Work"]) else {
                        fail("expected .command"); return
                    }
                    expect(cmd) == "list"
                }
                it("all arguments are passed through intact") {
                    guard case .command(_, let args) = parseArgs(["list", "Work"]) else {
                        fail("expected .command"); return
                    }
                    expect(args) == ["list", "Work"]
                }
            }
        }
    }
}
