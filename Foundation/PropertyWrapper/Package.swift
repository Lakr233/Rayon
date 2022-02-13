// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "PropertyWrapper",
    products: [
        .library(name: "PropertyWrapper", targets: ["PropertyWrapper"]),
    ],
    targets: [
        .target(name: "PropertyWrapper", dependencies: []),
    ]
)
