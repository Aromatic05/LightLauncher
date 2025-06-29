// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LightLauncher",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "LightLauncher", targets: ["LightLauncher"])
    ],
    targets: [
        .executableTarget(
            name: "LightLauncher",
            path: "Sources")
    ]
)
