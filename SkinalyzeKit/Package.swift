// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SkinalyzeKit",
    defaultLocalization: "en",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0"), // lets `swift test` run on the host Mac for fast feedback
    ],
    products: [
        .library(name: "SkinalyzeKit", targets: ["SkinalyzeKit"]),
    ],
    targets: [
        .target(
            name: "SkinalyzeKit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SkinalyzeKitTests",
            dependencies: ["SkinalyzeKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
