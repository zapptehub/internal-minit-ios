// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Feature-Game",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FeatureGame", targets: ["FeatureGame"])
    ],
    dependencies: [
        .package(path: "../Core-DesignSystem"),
        .package(path: "../Core-Extensions")
    ],
    targets: [
        .target(
            name: "FeatureGame",
            dependencies: [
                .product(name: "DesignSystem", package: "Core-DesignSystem"),
                .product(name: "CoreExtensions", package: "Core-Extensions")
            ],
            path: "Sources/FeatureGame"
        ),
        .testTarget(
            name: "FeatureGameTests",
            dependencies: ["FeatureGame"],
            path: "Tests/FeatureGameTests"
        )
    ]
)
