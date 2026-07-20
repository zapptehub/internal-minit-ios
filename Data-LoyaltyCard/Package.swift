// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Data-LoyaltyCard",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "DataLoyaltyCard", targets: ["DataLoyaltyCard"])
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk", .upToNextMajor(from: "12.0.0"))
    ],
    targets: [
        .target(
            name: "DataLoyaltyCard",
            dependencies: [
                .product(name: "FirebaseDatabase", package: "firebase-ios-sdk")
            ],
            path: "Sources/DataLoyaltyCard"
        ),
        .testTarget(
            name: "DataLoyaltyCardTests",
            dependencies: ["DataLoyaltyCard"],
            path: "Tests/DataLoyaltyCardTests"
        )
    ]
)
