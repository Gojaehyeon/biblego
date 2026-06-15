// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "biblego",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "biblego",
            dependencies: [
                "KeyboardShortcuts",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            resources: [
                .copy("Resources/bible.sqlite")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
