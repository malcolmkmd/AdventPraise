// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AdventPraisesKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "AdventPraiseKit",
            targets: [
                "Shared",
                "NumberPadFeature"
        ]),
        .library(
            name: "NumberPadFeature",
            targets: ["NumberPadFeature"]),
        .library(
            name: "Shared",
            targets: ["Shared"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "Shared",
            dependencies: [],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "SharedTests",
            dependencies: ["Shared"]),
        .target(
            name: "NumberPadFeature",
            dependencies: [
                "Shared",
                .product(
                    name: "ComposableArchitecture",
                    package: "swift-composable-architecture"),
            ]),
        .testTarget(
            name: "NumberPadFeatureTests",
            dependencies: ["NumberPadFeature"])
    ]
)
