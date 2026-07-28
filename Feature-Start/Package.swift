// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Feature-Start",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FeatureStart", targets: ["FeatureStart"])
    ],
    dependencies: [
        .package(path: "../Core-DesignSystem"),
        .package(path: "../Core-Extensions")
    ],
    targets: [
        .target(
            name: "FeatureStart",
            dependencies: [
                .product(name: "DesignSystem", package: "Core-DesignSystem"),
                .product(name: "CoreExtensions", package: "Core-Extensions")
            ],
            path: "Sources/FeatureStart",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "FeatureStartTests",
            dependencies: ["FeatureStart"],
            path: "Tests/FeatureStartTests"
        )
    ]
)
