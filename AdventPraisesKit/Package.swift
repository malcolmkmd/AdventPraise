// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AdventPraisesKit",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "AppFeature",
            targets: ["AppFeature"]),
        .library(
            name: "NumberPadFeature",
            targets: ["NumberPadFeature"]),
        .library(
            name: "HymnalPickerFeature",
            targets: ["HymnalPickerFeature"]),
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
                "NumberPadFeature",
                "HymnalPickerFeature"
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
            dependencies: [],
            resources: [.process("Resources")]
        ),
        .target(
            name: "NumberPadFeature",
            dependencies: [
                "Core",
                "CoreUI",
                "HymnalPickerFeature",
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
            dependencies: ["SearchFeature"]),
        .target(
            name: "HymnalPickerFeature",
            dependencies: [
                "Core",
                .product(
                    name: "ComposableArchitecture",
                    package: "swift-composable-architecture"),
            ]),
    ]
)
