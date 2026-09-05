// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UAPPKit",
    defaultLocalization: "pt-BR",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "UAPPKit", targets: ["UAPPKit"])
    ],
    targets: [
        .target(
            name: "UAPPKit",
            path: "Sources/UAPPKit"
        ),
        .testTarget(
            name: "UAPPKitTests",
            dependencies: ["UAPPKit"],
            path: "Tests/UAPPKitTests"
        )
    ]
)
