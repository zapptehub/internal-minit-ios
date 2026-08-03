// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Feature-Card",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FeatureCard", targets: ["FeatureCard"])
    ],
    dependencies: [
        .package(path: "../Core-DesignSystem"),
        .package(path: "../Core-Extensions")
    ],
    targets: [
        .target(
            name: "FeatureCard",
            dependencies: [
                .product(name: "DesignSystem", package: "Core-DesignSystem"),
                .product(name: "CoreExtensions", package: "Core-Extensions")
            ],
            path: "Sources/FeatureCard"
        ),
        .testTarget(
            name: "FeatureCardTests",
            dependencies: ["FeatureCard"],
            path: "Tests/FeatureCardTests"
        )
    ]
)
