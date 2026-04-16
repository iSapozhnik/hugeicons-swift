// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "hugeicons-swift",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Hugeicons",
            targets: ["Hugeicons"]
        ),
    ],
    targets: [
        .target(
            name: "Hugeicons",
            path: "Sources/Hugeicons",
            exclude: [
                "Resources/Hugeicons/name-map.json",
            ],
            resources: [
                .process("Resources/Hugeicons/Hugeicons.xcassets"),
            ]
        ),
        .testTarget(
            name: "HugeiconsTests",
            dependencies: ["Hugeicons"]
        ),
    ]
)
