// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LightLauncher",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "LightLauncher", targets: ["LightLauncher"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0")
    ],
    targets: [
        .executableTarget(
            name: "LightLauncher",
            dependencies: ["Yams"],
            path: "Sources",
            resources: [
                .process("Resources")
            ])
    ]
)
