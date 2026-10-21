// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Core-Networking",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "CoreNetworking", targets: ["CoreNetworking"]),
        // Test helper for contract fixtures, the hand-built contract JWT, and the
        // small contract client. The minit app target does not link this product.
        .library(name: "CoreNetworkingTestUtilities", targets: ["CoreNetworkingTestUtilities"])
    ],
    targets: [
        .target(
            name: "CoreNetworking",
            path: "Sources/CoreNetworking"
        ),
        .target(
            name: "CoreNetworkingTestUtilities",
            dependencies: ["CoreNetworking"],
            path: "Sources/CoreNetworkingTestUtilities",
            resources: [
                .copy("Resources/contract"),
                .copy("Resources/contract.sha256")
            ]
        ),
        .testTarget(
            name: "CoreNetworkingTests",
            dependencies: ["CoreNetworking", "CoreNetworkingTestUtilities"],
            path: "Tests/CoreNetworkingTests"
        )
    ]
)
