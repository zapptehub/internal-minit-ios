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
        .package(path: "../Core-Extensions")
    ],
    targets: [
        .target(
            name: "FeatureHome",
            dependencies: [
                .product(name: "DesignSystem", package: "Core-DesignSystem"),
                .product(name: "CoreExtensions", package: "Core-Extensions")
            ],
            path: "Sources/FeatureHome"
        ),
        .testTarget(
            name: "FeatureHomeTests",
            dependencies: ["FeatureHome"],
            path: "Tests/FeatureHomeTests"
        )
    ]
)
