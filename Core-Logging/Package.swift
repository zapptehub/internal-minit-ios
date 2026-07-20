// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Core-Logging",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "CoreLogging", targets: ["CoreLogging"])
    ],
    targets: [
        .target(
            name: "CoreLogging",
            path: "Sources/CoreLogging"
        )
    ]
)
