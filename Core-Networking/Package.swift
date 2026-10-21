// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Core-Networking",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "CoreNetworking", targets: ["CoreNetworking"]),
        // Test helper for contract fixtures (and, in task 4.7, the contract client).
        // The minit app target does not link this product.
        .library(name: "CoreNetworkingTestUtilities", targets: ["CoreNetworkingTestUtilities"])
    ],
    targets: [
        .target(
            name: "CoreNetworking",
            path: "Sources/CoreNetworking"
        ),
        .target(
            name: "CoreNetworkingTestUtilities",
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
