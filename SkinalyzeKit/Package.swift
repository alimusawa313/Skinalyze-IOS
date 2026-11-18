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
            swiftSettings: [
                .swiftLanguageMode(.v6),
                // The 3D maths (registration, fusion, texture baking) is ~60× slower unoptimised (12 s vs 0.2 s per
                // scan), and development devices run debug builds — so the kit is optimised in debug too.
                .unsafeFlags(["-O"], .when(configuration: .debug)),
            ]
        ),
        .testTarget(
            name: "SkinalyzeKitTests",
            dependencies: ["SkinalyzeKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
