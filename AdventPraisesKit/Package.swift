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
                "Core",
                "NumberPadFeature"
        ]),
        .library(
            name: "NumberPadFeature",
            targets: ["NumberPadFeature"]),
        .library(
            name: "Core",
            targets: ["Core"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "Core",
            dependencies: [],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"]),
        .target(
            name: "NumberPadFeature",
            dependencies: [
                "Core",
                .product(
                    name: "ComposableArchitecture",
                    package: "swift-composable-architecture"),
            ]),
        .testTarget(
            name: "NumberPadFeatureTests",
            dependencies: ["NumberPadFeature"])
    ]
)
