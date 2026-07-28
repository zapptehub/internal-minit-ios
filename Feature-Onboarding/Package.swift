// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Feature-Onboarding",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FeatureOnboarding", targets: ["FeatureOnboarding"]),
        .library(name: "OnboardingTestUtilities", targets: ["OnboardingTestUtilities"])
    ],
    dependencies: [
        .package(path: "../Data-LoyaltyCard"),
        .package(path: "../Data-Profile"),
        .package(path: "../Core-DesignSystem"),
        .package(path: "../Core-Extensions")
    ],
    targets: [
        .target(
            name: "FeatureOnboarding",
            dependencies: [
                .product(name: "DataLoyaltyCard", package: "Data-LoyaltyCard"),
                .product(name: "DataProfile", package: "Data-Profile"),
                .product(name: "DesignSystem", package: "Core-DesignSystem"),
                .product(name: "CoreExtensions", package: "Core-Extensions")
            ],
            path: "Sources/FeatureOnboarding",
            resources: [.process("Resources")]
        ),
        .target(
            name: "OnboardingTestUtilities",
            dependencies: ["FeatureOnboarding"],
            path: "Sources/OnboardingTestUtilities"
        ),
        .testTarget(
            name: "FeatureOnboardingTests",
            dependencies: [
                "FeatureOnboarding",
                "OnboardingTestUtilities",
                .product(name: "CoreExtensions", package: "Core-Extensions")
            ],
            path: "Tests/FeatureOnboardingTests"
        )
    ]
)
