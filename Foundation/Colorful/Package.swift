// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "Colorful",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .macOS(.v10_15),
        .watchOS(.v6),
    ],
    products: [
        .library(name: "Colorful", targets: ["Colorful"]),
    ],
    targets: [
        .target(name: "Colorful", dependencies: []),
    ]
)
