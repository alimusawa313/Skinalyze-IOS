// swift-tools-version: 6.0
import PackageDescription

// Detector benchmark (docs/redesign/ML-PLAN.md M0.4). Runs on the Mac with the app's own SkinalyzeKit pipeline.
// Usage: swift run -c release DetectorBench --data ~/SkinalyzeData/bench \
//          --model ../../Skinalyze/AIModel/acneObj28200.mlmodel --variant baseline
let package = Package(
    name: "DetectorBench",
    platforms: [.macOS("26.0")],
    dependencies: [
        .package(path: "../../SkinalyzeKit"),
    ],
    targets: [
        .target(
            name: "BenchCore",
            dependencies: [.product(name: "SkinalyzeKit", package: "SkinalyzeKit")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "DetectorBench",
            dependencies: ["BenchCore", .product(name: "SkinalyzeKit", package: "SkinalyzeKit")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "BenchCoreTests",
            dependencies: ["BenchCore", .product(name: "SkinalyzeKit", package: "SkinalyzeKit")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
