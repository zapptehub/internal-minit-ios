// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Feature-Home",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FeatureHome", targets: ["FeatureHome"])
    ],
    dependencies: [
        .package(path: "../Core-DesignSystem"),
        .package(path: "../Core-Extensions"),
        .package(path: "../Data-Profile"),
        .package(path: "../Core-Networking")
    ],
    targets: [
        .target(
            name: "FeatureHome",
            dependencies: [
                .product(name: "DesignSystem", package: "Core-DesignSystem"),
                .product(name: "CoreExtensions", package: "Core-Extensions"),
                .product(name: "DataProfile", package: "Data-Profile")
            ],
            path: "Sources/FeatureHome",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "FeatureHomeTests",
            dependencies: [
                "FeatureHome",
                .product(name: "DataProfile", package: "Data-Profile"),
                .product(name: "CoreNetworkingTestUtilities", package: "Core-Networking")
            ],
            path: "Tests/FeatureHomeTests"
        )
    ]
)
