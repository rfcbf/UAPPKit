// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "UAPPKit",
    defaultLocalization: "pt-BR",
    platforms: [
        .iOS(.v18),
        .macOS(.v13)
    ],
    products: [
        .library(name: "UAPPKit", targets: ["UAPPKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/guoyingtao/Mantis.git", exact: "3.1.0")
    ],
    targets: [
        .target(
            name: "UAPPKit",
            dependencies: [.product(name: "Mantis", package: "Mantis", condition: .when(platforms: [.iOS]))],
            path: "Sources/UAPPKit",
            exclude: ["Helper/StackedToasts.swift"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "UAPPKitTests",
            dependencies: ["UAPPKit"],
            path: "Tests/UAPPKitTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
