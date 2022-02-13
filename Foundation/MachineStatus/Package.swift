// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MachineStatus",
    platforms: [
        .macOS(.v11),
        .iOS(.v14),
        .watchOS(.v7),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "MachineStatus",
            targets: ["MachineStatus"]
        ),
    ],
    dependencies: [
        .package(name: "NSRemoteShell", path: "../NSRemoteShell"),
        .package(name: "XMLCoder", path: "../XMLCoder"),
    ],
    targets: [
        .target(
            name: "MachineStatus",
            dependencies: ["NSRemoteShell", "XMLCoder"]
        ),
    ]
)
