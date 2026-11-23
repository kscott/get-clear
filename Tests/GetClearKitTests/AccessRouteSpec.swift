// AccessRouteSpec.swift
//
// Tests for GetClearKit AccessRoute — helper vs direct store access.

import Foundation
import GetClearKit
import Testing

private func route(_ path: String) -> AccessRoute {
    AccessRoute.decide(resolvedExecutable: URL(fileURLWithPath: path))
}

@Suite("AccessRoute.decide")
struct AccessRouteTests {
    @Suite("inside the installed app")
    struct InsideApp {
        @Test("a command in the app's Helpers folder goes through the helper")
        func applicationsApp() {
            #expect(route("/Applications/Get Clear.app/Contents/Helpers/reminders")
                == .helper(appURL: URL(fileURLWithPath: "/Applications/Get Clear.app", isDirectory: true)))
        }

        @Test("the app works from a location other than /Applications")
        func userApplicationsApp() {
            #expect(route("/Users/someone/Applications/Get Clear.app/Contents/Helpers/text")
                == .helper(appURL: URL(fileURLWithPath: "/Users/someone/Applications/Get Clear.app", isDirectory: true)))
        }
    }

    @Suite("anywhere else")
    struct Elsewhere {
        @Test("a development build accesses the stores directly")
        func devBuild() {
            #expect(route("/Users/someone/dev/get-clear/.build/release/reminders-bin") == .direct)
        }

        @Test("a 1.3.x standalone binary accesses the stores directly")
        func standaloneBinary() {
            #expect(route("/usr/local/bin/reminders") == .direct)
        }

        @Test("a renamed copy of the app is not the installed app")
        func renamedApp() {
            #expect(route("/Applications/Get Clear 2.app/Contents/Helpers/reminders") == .direct)
        }

        @Test("the app's own executable never routes to itself")
        func appExecutable() {
            #expect(route("/Applications/Get Clear.app/Contents/MacOS/Get Clear") == .direct)
        }

        @Test("a Helpers folder outside an app bundle is not the app")
        func helpersWithoutBundle() {
            #expect(route("/tmp/Contents/Helpers/reminders") == .direct)
        }
    }
}
