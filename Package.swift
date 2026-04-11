// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "get-clear",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "GetClearKit", targets: ["GetClearKit"]),
        .executable(name: "get-clear", targets: ["GetClear"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Quick/Quick.git", from: "7.0.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "13.0.0"),
    ],
    targets: [
        .target(
            name: "GetClearKit",
            path: "Sources/GetClearKit"
        ),
        .executableTarget(
            name: "GetClear",
            dependencies: ["GetClearKit"],
            path: "Sources/GetClear",
            exclude: ["get-clear.entitlements"]
        ),
        // Test suite — run via: swift test
        .testTarget(
            name: "GetClearKitTests",
            dependencies: [
                "GetClearKit",
                .product(name: "Quick", package: "Quick"),
                .product(name: "Nimble", package: "Nimble"),
            ],
            path: "Tests/GetClearKitTests"
        ),
    ]
)
