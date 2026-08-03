// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Core-DesignSystem",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"])
    ],
    targets: [
        .target(
            name: "DesignSystem",
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
