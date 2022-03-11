// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "SPIndicator",
    platforms: [
        .iOS(.v12), .tvOS(.v12),
    ],
    products: [
        .library(
            name: "SPIndicator",
            targets: ["SPIndicator"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SPIndicator",
            swiftSettings: [
                .define("SPINDICATOR_SPM"),
            ]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
