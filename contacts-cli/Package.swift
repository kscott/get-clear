// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "contacts-cli",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic — no Apple framework dependencies, fully testable
        .target(
            name: "ContactsLib",
            path: "Sources/ContactsLib"
        ),
        // Main binary — depends on ContactsLib plus Contacts/AppKit
        .executableTarget(
            name: "contacts-bin",
            dependencies: ["ContactsLib"],
            path: "Sources/ContactsCLI",
            linkerSettings: [
                .linkedFramework("Contacts"),
                .linkedFramework("AppKit"),
            ]
        ),
        // Test runner — executable rather than XCTest target so it works
        // with just the Swift CLI toolchain (no Xcode required)
        .executableTarget(
            name: "contacts-tests",
            dependencies: ["ContactsLib"],
            path: "Tests/ContactsLibTests"
        ),
    ]
)
