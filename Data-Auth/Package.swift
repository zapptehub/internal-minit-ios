// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Data-Auth",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "DataAuth", targets: ["DataAuth"])
    ],
    dependencies: [
        .package(path: "../Core-Networking"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk", .upToNextMajor(from: "12.0.0"))
    ],
    targets: [
        .target(
            name: "DataAuth",
            dependencies: [
                .product(name: "CoreNetworking", package: "Core-Networking"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk")
            ],
            path: "Sources/DataAuth"
        ),
        .testTarget(
            name: "DataAuthTests",
            dependencies: [
                "DataAuth",
                .product(name: "CoreNetworking", package: "Core-Networking")
            ],
            path: "Tests/DataAuthTests"
        )
    ]
)
