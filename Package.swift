// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Consumer",
    products: [
        .library(name: "Consumer", targets: ["Consumer"]),
    ],
    targets: [
        .target(name: "Consumer", path: "Sources"),
        .testTarget(name: "ConsumerTests", dependencies: ["Consumer"], path: "Tests"),
    ]
)
