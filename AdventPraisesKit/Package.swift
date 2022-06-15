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
                "CoreUI",
                "AppFeature",
                "SearchFeature",
                "NumberPadFeature"
        ]),
        .library(
            name: "AppFeature",
            targets: ["AppFeature"]),
        .library(
            name: "NumberPadFeature",
            targets: ["NumberPadFeature"]),
        .library(
            name: "SearchFeature",
            targets: ["SearchFeature"]),
        .library(
            name: "Core",
            targets: ["Core"]),
        .library(
            name: "CoreUI",
            targets: ["CoreUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "AppFeature",
            dependencies: [
                "Core",
                "CoreUI",
                "SearchFeature",
                "NumberPadFeature"
            ]
        ),
        .target(
            name: "Core",
            dependencies: []
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"]),
        .target(
            name: "CoreUI",
            dependencies: []
        ),
        .target(
            name: "NumberPadFeature",
            dependencies: [
                "Core",
                "CoreUI",
                .product(
                    name: "ComposableArchitecture",
                    package: "swift-composable-architecture"),
            ]),
        .testTarget(
            name: "NumberPadFeatureTests",
            dependencies: ["NumberPadFeature"]),
        .target(
            name: "SearchFeature",
            dependencies: [
                "Core",
                "CoreUI",
                .product(
                    name: "ComposableArchitecture",
                    package: "swift-composable-architecture"),
            ]),
        .testTarget(
            name: "SearchFeatureTests",
            dependencies: ["SearchFeature"])
    ]
)
