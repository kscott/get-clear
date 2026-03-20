// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "get-clear",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "GetClearKit", targets: ["GetClearKit"]),
        .executable(name: "get-clear", targets: ["GetClear"]),
    ],
    targets: [
        .target(
            name: "GetClearKit",
            path: "Sources/GetClearKit"
        ),
        .executableTarget(
            name: "GetClear",
            dependencies: ["GetClearKit"],
            path: "Sources/GetClear"
        ),
        // Test runner — no Xcode required; run via: swift run getclearkit-tests
        .executableTarget(
            name: "getclearkit-tests",
            dependencies: ["GetClearKit"],
            path: "Tests/GetClearKitTests"
        ),
    ]
)
