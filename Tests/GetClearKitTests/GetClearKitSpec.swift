// GetClearKitSpec.swift
//
// Tests for GetClearKit utilities — TimespanFormatter, UpdateChecker, parseArgs.

import Foundation
import GetClearKit
import Testing

private let cal = Calendar.current

private func makeDate(_ hour: Int, _ minute: Int) -> Date {
    cal.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
}

@Suite("TimespanFormatter")
struct TimespanFormatterTests {
    @Suite("15-minute rounding")
    struct FifteenMinuteRounding {
        func rounded(_ h: Int, _ m: Int) -> Int {
            cal.component(.minute, from: TimespanFormatter.roundTo15Minutes(makeDate(h, m)))
        }

        func roundedHour(_ h: Int, _ m: Int) -> Int {
            cal.component(.hour, from: TimespanFormatter.roundTo15Minutes(makeDate(h, m)))
        }

        @Test("X:07 rounds down to X:00") func x07() {
            #expect(rounded(9, 7) == 0)
        }

        @Test("X:08 rounds up to X:15") func x08() {
            #expect(rounded(9, 8) == 15)
        }

        @Test("X:22 rounds down to X:15") func x22() {
            #expect(rounded(9, 22) == 15)
        }

        @Test("X:23 rounds up to X:30") func x23() {
            #expect(rounded(9, 23) == 30)
        }

        @Test("X:37 rounds down to X:30") func x37() {
            #expect(rounded(9, 37) == 30)
        }

        @Test("X:38 rounds up to X:45") func x38() {
            #expect(rounded(9, 38) == 45)
        }

        @Test("X:52 rounds down to X:45") func x52() {
            #expect(rounded(9, 52) == 45)
        }

        @Test("X:53 rounds up to the next hour")
        func x53() {
            #expect(rounded(9, 53) == 0)
            #expect(roundedHour(9, 53) == 10)
        }

        @Test("X:00 stays at X:00") func x00() {
            #expect(rounded(9, 0) == 0)
        }

        @Test("X:15 stays at X:15") func x15() {
            #expect(rounded(9, 15) == 15)
        }

        @Test("X:30 stays at X:30") func x30() {
            #expect(rounded(9, 30) == 30)
        }

        @Test("X:45 stays at X:45") func x45() {
            #expect(rounded(9, 45) == 45)
        }
    }

    @Suite("formatted output")
    struct FormattedOutput {
        let start = makeDate(9, 3) // rounds to 9:00am
        let end = makeDate(16, 47) // rounds to 4:45pm

        @Test("range includes the start time")
        func rangeIncludesStart() {
            #expect(TimespanFormatter.format(first: start, last: end).contains("9:00"))
        }

        @Test("range includes the end time")
        func rangeIncludesEnd() {
            #expect(TimespanFormatter.format(first: start, last: end).contains("4:45"))
        }

        @Test("range includes an arrow separator")
        func rangeIncludesArrow() {
            #expect(TimespanFormatter.format(first: start, last: end).contains("→"))
        }

        @Test("single entry shows only the start time")
        func singleEntryShowsStart() {
            #expect(TimespanFormatter.format(first: start, last: nil).contains("9:00"))
        }

        @Test("single entry has no arrow")
        func singleEntryNoArrow() {
            #expect(!TimespanFormatter.format(first: start, last: nil).contains("→"))
        }
    }

    @Suite("timespan from entries")
    struct TimespanFromEntries {
        @Test("returns nil for an empty entries array")
        func nilForEmptyEntries() {
            #expect(TimespanFormatter.timespan(from: []) == nil)
        }
    }
}

@Suite("UpdateChecker")
struct UpdateCheckerTests {
    @Suite("version comparison")
    struct VersionComparison {
        @Test("a newer patch version is newer") func newerPatch() {
            #expect(UpdateChecker.isNewer("1.1.3", than: "1.1.2"))
        }

        @Test("a newer minor version is newer") func newerMinor() {
            #expect(UpdateChecker.isNewer("1.2.0", than: "1.1.9"))
        }

        @Test("a newer major version is newer") func newerMajor() {
            #expect(UpdateChecker.isNewer("2.0.0", than: "1.9.9"))
        }

        @Test("the same version is not newer") func sameVersion() {
            #expect(!UpdateChecker.isNewer("1.1.2", than: "1.1.2"))
        }

        @Test("an older patch version is not newer") func olderPatch() {
            #expect(!UpdateChecker.isNewer("1.1.1", than: "1.1.2"))
        }

        @Test("an older minor version is not newer") func olderMinor() {
            #expect(!UpdateChecker.isNewer("1.0.9", than: "1.1.0"))
        }

        @Test("an older major version is not newer") func olderMajor() {
            #expect(!UpdateChecker.isNewer("1.9.9", than: "2.0.0"))
        }

        @Test("strips a leading 'v' prefix") func stripsV() {
            #expect(UpdateChecker.isNewer("v1.1.3", than: "1.1.2"))
        }

        @Test("handles a leading 'v' on both versions") func vOnBoth() {
            #expect(!UpdateChecker.isNewer("v1.1.2", than: "v1.1.2"))
        }
    }

    @Suite("cache")
    struct Cache {
        @Test("cachedLatest does not crash when no cache file exists")
        func cachedLatestNoCrash() {
            // Structural test — verifies no crash on missing file
            _ = UpdateChecker.cachedLatest()
            #expect(true)
        }
    }

    @Suite("hint")
    struct Hint {
        @Test("returns nil on a dev machine with no pkgutil receipt")
        func nilWithoutReceipt() {
            #expect(UpdateChecker.hint() == nil)
        }
    }
}

@Suite("parseArgs")
struct ParseArgsTests {
    @Suite("no arguments")
    struct NoArguments {
        @Test("empty array produces .empty")
        func emptyArray() {
            guard case .empty = parseArgs([]) else {
                Issue.record("expected .empty")
                return
            }
        }
    }

    @Suite("help flags")
    struct HelpFlags {
        @Test("'help' produces .help")
        func help() {
            guard case .help = parseArgs(["help"]) else { Issue.record("expected .help")
                return
            }
        }

        @Test("'--help' produces .help")
        func dashDashHelp() {
            guard case .help = parseArgs(["--help"]) else { Issue.record("expected .help")
                return
            }
        }

        @Test("'-h' produces .help")
        func dashH() {
            guard case .help = parseArgs(["-h"]) else { Issue.record("expected .help")
                return
            }
        }

        @Test("'help add' produces .help — subcommand help not yet supported")
        func helpSubcommand() {
            guard case .help = parseArgs(["help", "add"]) else { Issue.record("expected .help")
                return
            }
        }
    }

    @Suite("version flags")
    struct VersionFlags {
        @Test("'version' produces .version")
        func version() {
            guard case .version = parseArgs(["version"]) else { Issue.record("expected .version")
                return
            }
        }

        @Test("'--version' produces .version")
        func dashDashVersion() {
            guard case .version = parseArgs(["--version"]) else { Issue.record("expected .version")
                return
            }
        }

        @Test("'-v' produces .version")
        func dashV() {
            guard case .version = parseArgs(["-v"]) else { Issue.record("expected .version")
                return
            }
        }
    }

    // Note: '--help', '-h', 'help', '--version', '-v', 'version' after a command call
    // fail() → exit(). These are not testable without process isolation.

    @Suite("command dispatch")
    struct CommandDispatch {
        @Test("first argument becomes the command")
        func firstArgIsCommand() {
            guard case let .command(cmd, _) = parseArgs(["list", "Work"]) else {
                Issue.record("expected .command")
                return
            }
            #expect(cmd == "list")
        }

        @Test("all arguments are passed through intact")
        func argsPassedThrough() {
            guard case let .command(_, args) = parseArgs(["list", "Work"]) else {
                Issue.record("expected .command")
                return
            }
            #expect(args == ["list", "Work"])
        }
    }
}
