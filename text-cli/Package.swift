// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "text-cli",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/kscott/get-clear.git", branch: "main"),
        .package(url: "https://github.com/Quick/Quick.git", from: "7.0.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "13.0.0"),
    ],
    targets: [
        // Pure logic — no framework dependencies, fully testable
        .target(
            name: "TextLib",
            path: "Sources/TextLib"
        ),
        // Main binary — Contacts for lookup, osascript for sending via Messages.app
        .executableTarget(
            name: "text-bin",
            dependencies: [
                "TextLib",
                .product(name: "GetClearKit", package: "get-clear"),
            ],
            path: "Sources/TextCLI",
            linkerSettings: [
                .linkedFramework("Contacts"),
            ]
        ),
        // Test suite — run via: swift test
        .testTarget(
            name: "TextLibTests",
            dependencies: [
                "TextLib",
                .product(name: "Quick", package: "Quick"),
                .product(name: "Nimble", package: "Nimble"),
            ],
            path: "Tests/TextLibTests"
        ),
    ]
)
