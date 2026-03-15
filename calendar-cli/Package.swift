// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "calendar-cli",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/kscott/get-clear", branch: "main"),
    ],
    targets: [
        // Pure logic — no Apple framework dependencies, fully testable
        .target(
            name: "CalendarLib",
            path: "Sources/CalendarLib"
        ),
        // Main binary — depends on CalendarLib plus EventKit/AppKit
        .executableTarget(
            name: "calendar-bin",
            dependencies: [
                "CalendarLib",
                .product(name: "GetClearKit", package: "get-clear"),
            ],
            path: "Sources/CalendarCLI",
            linkerSettings: [
                .linkedFramework("EventKit"),
                .linkedFramework("AppKit"),
            ]
        ),
        // Test runner — executable rather than XCTest target so it works
        // with just the Swift CLI toolchain (no Xcode required)
        .executableTarget(
            name: "calendar-tests",
            dependencies: [
                "CalendarLib",
                .product(name: "GetClearKit", package: "get-clear"),
            ],
            path: "Tests/CalendarLibTests"
        ),
    ]
)
