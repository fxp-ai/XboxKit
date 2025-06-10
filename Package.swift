// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "XboxKit", platforms: [.macOS(.v15), .iOS(.v18)],
    products: [.library(name: "XboxKit", targets: ["XboxKit"])],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "XboxKit",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ], resources: [.process("Resources/market-data.plist"), .process("Resources/language-data.plist")], ),
        .testTarget(name: "XboxKitTests", dependencies: [.byName(name: "XboxKit")]),
    ])
