// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "calendar-cli",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/kscott/get-clear.git", branch: "main"),
        .package(url: "https://github.com/Quick/Quick.git", from: "7.0.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "13.0.0"),
    ],
    targets: [
        // Pure logic — no Apple framework dependencies, fully testable
        .target(
            name: "CalendarLib",
            dependencies: [
                .product(name: "GetClearKit", package: "get-clear"),
            ],
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
        // Test suite — run via: swift test
        .testTarget(
            name: "CalendarLibTests",
            dependencies: [
                "CalendarLib",
                .product(name: "GetClearKit", package: "get-clear"),
                .product(name: "Quick", package: "Quick"),
                .product(name: "Nimble", package: "Nimble"),
            ],
            path: "Tests/CalendarLibTests"
        ),
    ]
)
