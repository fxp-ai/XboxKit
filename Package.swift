// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GamePassKit", platforms: [.macOS(.v15)], products: [.library(name: "GamePassKit", targets: ["GamePassKit"])],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "GamePassKit",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
            ], resources: [.process("countries.plist"), .process("languages.plist")], ),
        .testTarget(name: "GamePassKitTests", dependencies: [.byName(name: "GamePassKit")]),
    ])
