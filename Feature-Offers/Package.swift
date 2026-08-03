// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Feature-Offers",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FeatureOffers", targets: ["FeatureOffers"])
    ],
    dependencies: [
        .package(path: "../Core-DesignSystem"),
        .package(path: "../Core-Extensions")
    ],
    targets: [
        .target(
            name: "FeatureOffers",
            dependencies: [
                .product(name: "DesignSystem", package: "Core-DesignSystem"),
                .product(name: "CoreExtensions", package: "Core-Extensions")
            ],
            path: "Sources/FeatureOffers"
        ),
        .testTarget(
            name: "FeatureOffersTests",
            dependencies: ["FeatureOffers"],
            path: "Tests/FeatureOffersTests"
        )
    ]
)
