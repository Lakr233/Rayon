// swift-tools-version: 5.5

import PackageDescription

let package = Package(
    name: "NSRemoteShell",
    products: [
        .library(
            name: "NSRemoteShell",
            targets: ["NSRemoteShell"]
        ),
    ],
    dependencies: [
        .package(name: "CSSH", path: "External/CSSH"),
    ],
    targets: [
        .target(
            name: "NSRemoteShell",
            dependencies: ["CSSH"]
        ),
    ]
)
