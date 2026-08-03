// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Feature-Map",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FeatureMap", targets: ["FeatureMap"])
    ],
    dependencies: [
        .package(path: "../Core-DesignSystem"),
        .package(path: "../Core-Extensions")
    ],
    targets: [
        .target(
            name: "FeatureMap",
            dependencies: [
                .product(name: "DesignSystem", package: "Core-DesignSystem"),
                .product(name: "CoreExtensions", package: "Core-Extensions")
            ],
            path: "Sources/FeatureMap"
        ),
        .testTarget(
            name: "FeatureMapTests",
            dependencies: ["FeatureMap"],
            path: "Tests/FeatureMapTests"
        )
    ]
)
