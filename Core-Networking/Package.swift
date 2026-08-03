// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Core-Networking",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "CoreNetworking", targets: ["CoreNetworking"])
    ],
    targets: [
        .target(
            name: "CoreNetworking",
            path: "Sources/CoreNetworking"
        ),
        .testTarget(
            name: "CoreNetworkingTests",
            dependencies: ["CoreNetworking"],
            path: "Tests/CoreNetworkingTests"
        )
    ]
)
