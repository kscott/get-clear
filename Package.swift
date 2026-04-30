// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "get-clear",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "GetClearKit", targets: ["GetClearKit"]),
        .executable(name: "get-clear", targets: ["GetClear"]),
        .executable(name: "reminders-bin", targets: ["reminders-bin"]),
        .executable(name: "calendar-bin", targets: ["calendar-bin"]),
        .executable(name: "contacts-bin", targets: ["contacts-bin"]),
        .executable(name: "mail-bin", targets: ["mail-bin"]),
        .executable(name: "text-bin", targets: ["text-bin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Quick/Quick.git", from: "7.0.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "13.0.0"),
    ],
    targets: [

        // MARK: - GetClearKit

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
        .testTarget(
            name: "GetClearKitTests",
            dependencies: [
                "GetClearKit",
                .product(name: "Quick", package: "Quick"),
                .product(name: "Nimble", package: "Nimble"),
            ],
            path: "Tests/GetClearKitTests"
        ),

        // MARK: - ContactKit (pure shared contact types and matching)

        .target(
            name: "ContactKit",
            dependencies: ["GetClearKit"],
            path: "Sources/ContactKit",
            exclude: ["README.md"]
        ),
        .target(
            name: "ContactTestSupport",
            dependencies: ["ContactKit"],
            path: "Tests/ContactTestSupport"
        ),
        .testTarget(
            name: "ContactKitTests",
            dependencies: [
                "ContactKit", "GetClearKit", "ContactTestSupport",
                .product(name: "Quick", package: "Quick"),
                .product(name: "Nimble", package: "Nimble"),
            ],
            path: "Tests/ContactKitTests"
        ),

        // MARK: - AppleContactKit (Apple Contacts framework boundary)

        .target(
            name: "AppleContactKit",
            dependencies: ["ContactKit"],
            path: "Sources/AppleContactKit",
            linkerSettings: [.linkedFramework("Contacts")]
        ),
        .testTarget(
            name: "AppleContactKitTests",
            dependencies: [
                "AppleContactKit",
                "ContactKit",
                .product(name: "Quick", package: "Quick"),
                .product(name: "Nimble", package: "Nimble"),
            ],
            path: "Tests/AppleContactKitTests"
        ),

        // MARK: - ContactStoreFactory (backend selection; shared by all contact-using binaries)

        .target(
            name: "ContactStoreFactory",
            dependencies: ["ContactKit", "AppleContactKit", "GetClearKit"],
            path: "Sources/ContactStoreFactory",
            linkerSettings: [.linkedFramework("Contacts")]
        ),

        // MARK: - reminders

        .target(
            name: "RemindersLib",
            dependencies: ["GetClearKit"],
            path: "reminders-cli/Sources/RemindersLib"
        ),
        .target(
            name: "RemindersEventKit",
            dependencies: ["RemindersLib", "GetClearKit"],
            path: "reminders-cli/Sources/RemindersEventKit"
        ),
        .executableTarget(
            name: "reminders-bin",
            dependencies: ["RemindersEventKit", "GetClearKit"],
            path: "reminders-cli/Sources/RemindersCLI",
            linkerSettings: [
                .linkedFramework("EventKit"),
                .linkedFramework("AppKit"),
            ]
        ),
        .testTarget(
            name: "RemindersLibTests",
            dependencies: [
                "RemindersLib",
                "GetClearKit",
                .product(name: "Quick", package: "Quick"),
                .product(name: "Nimble", package: "Nimble"),
            ],
            path: "reminders-cli/Tests/RemindersLibTests"
        ),

        // MARK: - calendar

        .target(
            name: "CalendarLib",
            dependencies: ["GetClearKit"],
            path: "calendar-cli/Sources/CalendarLib"
        ),
        .target(
            name: "CalendarEventKit",
            dependencies: ["CalendarLib", "GetClearKit"],
            path: "calendar-cli/Sources/CalendarEventKit"
        ),
        .executableTarget(
            name: "calendar-bin",
            dependencies: ["CalendarEventKit", "CalendarLib", "GetClearKit"],
            path: "calendar-cli/Sources/CalendarCLI",
            linkerSettings: [
                .linkedFramework("EventKit"),
                .linkedFramework("AppKit"),
            ]
        ),
        .testTarget(
            name: "CalendarLibTests",
            dependencies: [
                "CalendarLib",
                "GetClearKit",
                .product(name: "Quick", package: "Quick"),
                .product(name: "Nimble", package: "Nimble"),
            ],
            path: "calendar-cli/Tests/CalendarLibTests"
        ),

        // MARK: - contacts

        .target(
            name: "ContactsLib",
            dependencies: ["ContactKit", "GetClearKit"],
            path: "contacts-cli/Sources/ContactsLib"
        ),
        .executableTarget(
            name: "contacts-bin",
            dependencies: ["ContactsLib", "ContactStoreFactory", "GetClearKit"],
            path: "contacts-cli/Sources/ContactsCLI",
            linkerSettings: [.linkedFramework("AppKit")]
        ),
        .testTarget(
            name: "ContactsLibTests",
            dependencies: [
                "ContactsLib", "ContactKit", "GetClearKit", "ContactTestSupport",
                .product(name: "Quick", package: "Quick"),
                .product(name: "Nimble", package: "Nimble"),
            ],
            path: "contacts-cli/Tests/ContactsLibTests"
        ),

        // MARK: - mail

        .target(
            name: "MailLib",
            dependencies: ["GetClearKit", "ContactKit"],
            path: "mail-cli/Sources/MailLib"
        ),
        .target(
            name: "MailJMAP",
            dependencies: ["MailLib", "GetClearKit"],
            path: "mail-cli/Sources/MailJMAP"
        ),
        .target(
            name: "MailClientFactory",
            dependencies: ["MailLib", "MailJMAP"],
            path: "mail-cli/Sources/MailClientFactory"
        ),
        .executableTarget(
            name: "mail-bin",
            dependencies: ["MailClientFactory", "MailLib", "ContactStoreFactory", "GetClearKit"],
            path: "mail-cli/Sources/MailCLI",
            linkerSettings: [
                .linkedFramework("AppKit"),
            ]
        ),
        .testTarget(
            name: "MailLibTests",
            dependencies: [
                "MailLib", "ContactKit", "ContactTestSupport", "GetClearKit",
                .product(name: "Quick", package: "Quick"),
                .product(name: "Nimble", package: "Nimble"),
            ],
            path: "mail-cli/Tests/MailLibTests"
        ),

        // MARK: - text

        .target(
            name: "TextLib",
            dependencies: ["GetClearKit", "ContactKit"],
            path: "text-cli/Sources/TextLib"
        ),
        .target(
            name: "TextMessages",
            dependencies: ["TextLib", "ContactKit"],
            path: "text-cli/Sources/TextMessages"
        ),
        .executableTarget(
            name: "text-bin",
            dependencies: ["TextMessages", "TextLib", "ContactStoreFactory", "GetClearKit"],
            path: "text-cli/Sources/TextCLI",
            linkerSettings: [
                .linkedFramework("AppKit"),
            ]
        ),
        .testTarget(
            name: "TextLibTests",
            dependencies: [
                "TextLib",
                "ContactKit",
                .product(name: "Quick", package: "Quick"),
                .product(name: "Nimble", package: "Nimble"),
            ],
            path: "text-cli/Tests/TextLibTests"
        ),
    ]
)
