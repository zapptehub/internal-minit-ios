// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Core-DesignSystem",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"])
    ],
    dependencies: [
        .package(path: "../Core-Extensions")
    ],
    targets: [
        .target(
            name: "DesignSystem",
            dependencies: [
                .product(name: "CoreExtensions", package: "Core-Extensions")
            ],
            path: "Sources/DesignSystem",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "DesignSystemTests",
            dependencies: ["DesignSystem"],
            path: "Tests/DesignSystemTests"
        )
    ]
)
