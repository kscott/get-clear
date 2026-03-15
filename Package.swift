// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "get-clear",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "GetClearKit", targets: ["GetClearKit"]),
    ],
    targets: [
        .target(
            name: "GetClearKit",
            path: "Sources/GetClearKit"
        ),
        // Test runner — no Xcode required; run via: swift run getclearkit-tests
        .executableTarget(
            name: "getclearkit-tests",
            dependencies: ["GetClearKit"],
            path: "Tests/GetClearKitTests"
        ),
    ]
)
