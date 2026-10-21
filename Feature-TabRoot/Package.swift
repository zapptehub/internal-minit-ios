// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Feature-TabRoot",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FeatureTabRoot", targets: ["FeatureTabRoot"])
    ],
    dependencies: [
        .package(path: "../Core-DesignSystem"),
        .package(path: "../Core-Extensions"),
        .package(path: "../Data-Profile"),
        .package(path: "../Core-Networking"),
        .package(path: "../Feature-Home"),
        .package(path: "../Feature-Offers"),
        .package(path: "../Feature-Map"),
        .package(path: "../Feature-Card"),
        .package(path: "../Feature-Game")
    ],
    targets: [
        .target(
            name: "FeatureTabRoot",
            dependencies: [
                .product(name: "DesignSystem", package: "Core-DesignSystem"),
                .product(name: "CoreExtensions", package: "Core-Extensions"),
                .product(name: "DataProfile", package: "Data-Profile"),
                .product(name: "CoreNetworking", package: "Core-Networking"),
                .product(name: "FeatureHome", package: "Feature-Home"),
                .product(name: "FeatureOffers", package: "Feature-Offers"),
                .product(name: "FeatureMap", package: "Feature-Map"),
                .product(name: "FeatureCard", package: "Feature-Card"),
                .product(name: "FeatureGame", package: "Feature-Game")
            ],
            path: "Sources/FeatureTabRoot"
        ),
        .testTarget(
            name: "FeatureTabRootTests",
            dependencies: [
                "FeatureTabRoot",
                .product(name: "DataProfile", package: "Data-Profile"),
                .product(name: "CoreNetworking", package: "Core-Networking"),
                .product(name: "FeatureHome", package: "Feature-Home")
            ],
            path: "Tests/FeatureTabRootTests"
        )
    ]
)
