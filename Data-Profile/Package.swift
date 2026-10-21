// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Data-Profile",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "DataProfile", targets: ["DataProfile"])
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk", .upToNextMajor(from: "12.0.0")),
        .package(path: "../Core-Networking"),
        .package(path: "../Data-LoyaltyCard")
    ],
    targets: [
        .target(
            name: "DataProfile",
            dependencies: [
                .product(name: "FirebaseDatabase", package: "firebase-ios-sdk"),
                .product(name: "CoreNetworking", package: "Core-Networking")
            ],
            path: "Sources/DataProfile"
        ),
        .testTarget(
            name: "DataProfileTests",
            dependencies: [
                "DataProfile",
                .product(name: "DataLoyaltyCard", package: "Data-LoyaltyCard"),
                .product(name: "CoreNetworking", package: "Core-Networking"),
                .product(name: "CoreNetworkingTestUtilities", package: "Core-Networking")
            ],
            path: "Tests/DataProfileTests"
        )
    ]
)
