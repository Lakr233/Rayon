// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Keychain",
    products: [
        .library(
            name: "Keychain",
            targets: ["Keychain"]
        ),
    ],
    targets: [
        .target(
            name: "Keychain",
            dependencies: []
        ),
    ]
)
