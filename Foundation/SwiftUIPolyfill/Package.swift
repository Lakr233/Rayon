// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftUIPolyfill",
    platforms: [
        .iOS(.v14),
    ],
    products: [
        .library(
            name: "SwiftUIPolyfill",
            type: .static,
            targets: ["SwiftUIPolyfill"]
        ),
        // so we can save disk space for menubar app
//        .library(
//            name: "SwiftUIPolyfill-Framework",
//            type: .dynamic,
//            targets: ["SwiftUIPolyfill"]
//        ),
    ],
    dependencies: [
        .package(name: "PropertyWrapper", path: "../PropertyWrapper"),
        .package(name: "Keychain", path: "../Keychain"),
    ],
    targets: [
        .target(
            name: "SwiftUIPolyfill",
            dependencies: [
                "Keychain",
                "PropertyWrapper",
            ]
        ),
    ]
)
