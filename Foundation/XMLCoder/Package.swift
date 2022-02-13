// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "XMLCoder",
    products: [
        .library(
            name: "XMLCoder",
            targets: ["XMLCoder"]
        ),
    ],
    targets: [
        .target(
            name: "XMLCoder",
            dependencies: []
        ),
    ]
)
