// UpdateCheckerSpec.swift
//
// Tests for GetClearKit UpdateChecker's pure parts: reading GitHub's release response, the
// shared cache file, and an app's version. (isNewer is covered in GetClearKitSpec.)

import Foundation
import GetClearKit
import Testing

private func releaseJSON(tag: String, assets: [String]) -> Data {
    let list = assets.map { "{\"name\":\"\($0)\",\"browser_download_url\":\"https://dl/\($0)\"}" }.joined(separator: ",")
    return Data("{\"tag_name\":\"\(tag)\",\"assets\":[\(list)]}".utf8)
}

@Suite("UpdateChecker release and cache reading")
struct UpdateCheckerReadingTests {
    @Suite("parseLatestRelease")
    struct ParseLatestRelease {
        @Test("a release with both assets yields the version and both download addresses")
        func bothAssets() {
            #expect(UpdateChecker.parseLatestRelease(releaseJSON(tag: "v1.4.0", assets: ["get-clear.pkg", "Get-Clear.zip"]))
                == LatestRelease(version: "1.4.0", pkgURL: "https://dl/get-clear.pkg", appURL: "https://dl/Get-Clear.zip"))
        }

        @Test("a release from before self-update has no app archive")
        func pkgOnly() {
            #expect(UpdateChecker.parseLatestRelease(releaseJSON(tag: "v1.3.5", assets: ["get-clear.pkg"]))?.appURL == nil)
        }

        @Test("a release without a PKG is ignored")
        func noPkg() {
            #expect(UpdateChecker.parseLatestRelease(releaseJSON(tag: "v1.4.0", assets: ["Get-Clear.zip"])) == nil)
        }

        @Test("the rolling 'latest' tag carries no version and is ignored")
        func rollingTag() {
            #expect(UpdateChecker.parseLatestRelease(releaseJSON(tag: "latest", assets: ["get-clear.pkg"])) == nil)
        }

        @Test("a response that isn't a release is ignored")
        func notARelease() {
            #expect(UpdateChecker.parseLatestRelease(Data("{\"message\":\"rate limited\"}".utf8)) == nil)
        }
    }

    @Suite("parseCache")
    struct ParseCache {
        @Test("a cache written by 1.3.x reads as a release with no app archive")
        func legacyCache() {
            let data = Data(
                "{\"version\":\"1.3.5\",\"url\":\"https://dl/get-clear.pkg\",\"checked\":\"2026-11-23T17:00:00Z\"}".utf8
            )
            #expect(UpdateChecker.parseCache(data)?.release
                == LatestRelease(version: "1.3.5", pkgURL: "https://dl/get-clear.pkg", appURL: nil))
        }

        @Test("a cache with an app archive keeps its address")
        func withAppURL() {
            let data = Data(
                "{\"version\":\"1.4.0\",\"url\":\"p\",\"appURL\":\"https://dl/Get-Clear.zip\",\"checked\":\"2026-11-23T17:00:00Z\"}".utf8
            )
            #expect(UpdateChecker.parseCache(data)?.release.appURL == "https://dl/Get-Clear.zip")
        }

        @Test("a cache without a check time is unreadable")
        func missingChecked() {
            #expect(UpdateChecker.parseCache(Data("{\"version\":\"1.4.0\",\"url\":\"p\"}".utf8)) == nil)
        }
    }

    @Suite("appVersion")
    struct AppVersion {
        @Test("reads the app's short version string")
        func readsVersion() {
            #expect(UpdateChecker.appVersion(fromInfo: ["CFBundleShortVersionString": "1.4.0", "CFBundleVersion": "99"]) == "1.4.0")
        }

        @Test("is nil when the Info.plist has no version")
        func missing() {
            #expect(UpdateChecker.appVersion(fromInfo: [:]) == nil)
        }
    }
}
