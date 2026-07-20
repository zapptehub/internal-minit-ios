// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Feature-Login",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FeatureLogin", targets: ["FeatureLogin"]),
        .library(name: "LoginTestUtilities", targets: ["LoginTestUtilities"])
    ],
    dependencies: [
        .package(path: "../Data-Auth"),
        .package(path: "../Core-DesignSystem"),
        .package(path: "../Core-Extensions")
    ],
    targets: [
        .target(
            name: "FeatureLogin",
            dependencies: [
                .product(name: "DataAuth", package: "Data-Auth"),
                .product(name: "DesignSystem", package: "Core-DesignSystem"),
                .product(name: "CoreExtensions", package: "Core-Extensions")
            ],
            path: "Sources/FeatureLogin",
            resources: [.process("Resources")]
        ),
        .target(
            name: "LoginTestUtilities",
            dependencies: ["FeatureLogin"],
            path: "Sources/LoginTestUtilities"
        ),
        .testTarget(
            name: "FeatureLoginTests",
            dependencies: ["FeatureLogin", "LoginTestUtilities"],
            path: "Tests/FeatureLoginTests"
        )
    ]
)
