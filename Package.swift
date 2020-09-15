// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "swiftui-apnsManager",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "APNSManager",
            targets: ["APNSManager"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "APNSManager",
            dependencies: []),
    ]
)
