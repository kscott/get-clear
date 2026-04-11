// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "contacts-cli",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/kscott/get-clear.git", branch: "main"),
        .package(url: "https://github.com/Quick/Quick.git", from: "7.0.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "13.0.0"),
    ],
    targets: [
        // Pure logic — no Apple framework dependencies, fully testable
        .target(
            name: "ContactsLib",
            path: "Sources/ContactsLib"
        ),
        // Main binary — depends on ContactsLib plus Contacts/AppKit
        .executableTarget(
            name: "contacts-bin",
            dependencies: [
                "ContactsLib",
                .product(name: "GetClearKit", package: "get-clear"),
            ],
            path: "Sources/ContactsCLI",
            linkerSettings: [
                .linkedFramework("Contacts"),
                .linkedFramework("AppKit"),
            ]
        ),
        // Test suite — run via: swift test
        .testTarget(
            name: "ContactsLibTests",
            dependencies: [
                "ContactsLib",
                .product(name: "Quick", package: "Quick"),
                .product(name: "Nimble", package: "Nimble"),
            ],
            path: "Tests/ContactsLibTests"
        ),
    ]
)
