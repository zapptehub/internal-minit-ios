// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Data-LoyaltyCard",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "DataLoyaltyCard", targets: ["DataLoyaltyCard"])
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk", .upToNextMajor(from: "12.0.0")),
        .package(path: "../Core-Networking")
    ],
    targets: [
        .target(
            name: "DataLoyaltyCard",
            dependencies: [
                .product(name: "FirebaseDatabase", package: "firebase-ios-sdk"),
                .product(name: "CoreNetworking", package: "Core-Networking")
            ],
            path: "Sources/DataLoyaltyCard"
        ),
        .testTarget(
            name: "DataLoyaltyCardTests",
            dependencies: [
                "DataLoyaltyCard",
                .product(name: "CoreNetworking", package: "Core-Networking"),
                .product(name: "CoreNetworkingTestUtilities", package: "Core-Networking")
            ],
            path: "Tests/DataLoyaltyCardTests"
        )
    ]
)
