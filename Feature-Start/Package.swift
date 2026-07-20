// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Feature-Start",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FeatureStart", targets: ["FeatureStart"])
    ],
    dependencies: [
        .package(path: "../Core-DesignSystem")
    ],
    targets: [
        .target(
            name: "FeatureStart",
            dependencies: [
                .product(name: "DesignSystem", package: "Core-DesignSystem")
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
