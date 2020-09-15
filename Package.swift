// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "swiftui-apnsManager",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "swiftui-apnsManager",
            targets: ["swiftui-apnsManager"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "swiftui-apnsManager",
            dependencies: []),
    ]
)
