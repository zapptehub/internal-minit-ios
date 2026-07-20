// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Core-Analytics",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "CoreAnalytics", targets: ["CoreAnalytics"])
    ],
    targets: [
        .target(
            name: "CoreAnalytics",
            path: "Sources/CoreAnalytics"
        )
    ]
)
