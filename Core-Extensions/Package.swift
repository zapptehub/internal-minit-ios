// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Core-Extensions",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "CoreExtensions", targets: ["CoreExtensions"])
    ],
    targets: [
        .target(
            name: "CoreExtensions",
            path: "Sources/CoreExtensions"
        ),
        .testTarget(
            name: "CoreExtensionsTests",
            dependencies: ["CoreExtensions"],
            path: "Tests/CoreExtensionsTests"
        )
    ]
)
