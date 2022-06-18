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
            name: "HomeFeature",
            targets: ["HomeFeature"]),
        .library(
            name: "LanguagePickerFeature",
            targets: ["LanguagePickerFeature"]),
        .library(
            name: "Core",
            targets: ["Core"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "AppFeature",
            dependencies: [
                "Core",
                "HomeFeature",
                "LanguagePickerFeature"
            ]
        ),
        .target(
            name: "Core",
            dependencies: [],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"]),
        .target(
            name: "HomeFeature",
            dependencies: [
                "Core",
                "LanguagePickerFeature",
                .product(
                    name: "ComposableArchitecture",
                    package: "swift-composable-architecture"),
            ]),
        .testTarget(
            name: "HomeFeatureTests",
            dependencies: ["HomeFeature"]),
        .target(
            name: "LanguagePickerFeature",
            dependencies: [
                "Core",
                .product(
                    name: "ComposableArchitecture",
                    package: "swift-composable-architecture"),
            ]),
    ]
)
