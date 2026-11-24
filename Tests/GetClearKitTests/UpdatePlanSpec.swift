// UpdatePlanSpec.swift
//
// Tests for GetClearKit UpdatePlan — what `get-clear update` does.

import Foundation
import GetClearKit
import Testing

private let appURL = URL(fileURLWithPath: "/Applications/Get Clear.app", isDirectory: true)
private let zip = URL(fileURLWithPath: "/downloads/Get-Clear.zip")
private let pkg = URL(fileURLWithPath: "/downloads/get-clear.pkg")

private func app(_ version: String, writable: Bool = true) -> InstalledApp {
    InstalledApp(url: appURL, version: version, writable: writable)
}

@Suite("UpdatePlan.decide")
struct UpdatePlanTests {
    @Test("a development build has nothing to update")
    func devBuild() {
        #expect(UpdatePlan.decide(installed: nil, latest: "1.4.0", appAsset: zip, pkgAsset: pkg) == .notInstalledAsApp)
    }

    @Test("the same version is up to date")
    func sameVersion() {
        #expect(UpdatePlan.decide(installed: app("1.4.0"), latest: "1.4.0", appAsset: zip, pkgAsset: pkg) == .upToDate("1.4.0"))
    }

    @Test("an older latest release is still up to date")
    func olderLatest() {
        #expect(UpdatePlan.decide(installed: app("1.4.1"), latest: "1.4.0", appAsset: zip, pkgAsset: pkg) == .upToDate("1.4.1"))
    }

    @Test("a newer release with an app archive and a writable app updates in place")
    func selfUpdate() {
        #expect(UpdatePlan.decide(installed: app("1.4.0"), latest: "1.5.0", appAsset: zip, pkgAsset: pkg)
            == .selfUpdate(from: "1.4.0", to: "1.5.0", asset: zip))
    }

    @Test("an app the user can't replace falls back to the installer, naming its folder")
    func notWritable() {
        #expect(UpdatePlan.decide(installed: app("1.4.0", writable: false), latest: "1.5.0", appAsset: zip, pkgAsset: pkg)
            == .pkgFallback(from: "1.4.0", to: "1.5.0", asset: pkg, reason: .notWritable(folder: URL(fileURLWithPath: "/Applications/"))))
    }

    @Test("a release without an app archive falls back to the installer")
    func noAppAsset() {
        #expect(UpdatePlan.decide(installed: app("1.4.0"), latest: "1.5.0", appAsset: nil, pkgAsset: pkg)
            == .pkgFallback(from: "1.4.0", to: "1.5.0", asset: pkg, reason: .noAppAsset))
    }
}
