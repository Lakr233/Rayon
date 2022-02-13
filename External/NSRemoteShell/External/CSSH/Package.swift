// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "CSSH",
    products: [
        .library(name: "CSSH", targets: ["CSSH"]),
    ],
    targets: [
        .binaryTarget(name: "CSSH", path: "CSSH.xcframework"),
    ]
)
