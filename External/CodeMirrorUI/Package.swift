// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CodeMirrorUI",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
    ],
    products: [
        .library(
            name: "CodeMirrorUI",
            targets: ["CodeMirrorUI"]
        ),
    ],
    targets: [
        .target(
            name: "CodeMirrorUI",
            resources: [.copy("ress")]
        ),
    ]
)
