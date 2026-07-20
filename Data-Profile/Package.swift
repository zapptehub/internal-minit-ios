// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Data-Profile",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "DataProfile", targets: ["DataProfile"])
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk", .upToNextMajor(from: "12.0.0"))
    ],
    targets: [
        .target(
            name: "DataProfile",
            dependencies: [
                .product(name: "FirebaseDatabase", package: "firebase-ios-sdk")
            ],
            path: "Sources/DataProfile"
        ),
        .testTarget(
            name: "DataProfileTests",
            dependencies: ["DataProfile"],
            path: "Tests/DataProfileTests"
        )
    ]
)
