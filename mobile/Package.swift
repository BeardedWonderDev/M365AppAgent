// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "M365AgentApp",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(name: "M365AgentApp", targets: ["M365AgentApp"]),
    ],
    dependencies: [
        // Skip Framework dependencies
        .package(url: "https://source.skip.tools/skip.git", from: "1.0.0"),
        .package(url: "https://source.skip.tools/skip-ui.git", from: "1.0.0"),
        .package(url: "https://source.skip.tools/skip-foundation.git", from: "1.0.0"),
        .package(url: "https://source.skip.tools/skip-test.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "M365AgentApp",
            dependencies: [
                .product(name: "Skip", package: "skip"),
                .product(name: "SkipUI", package: "skip-ui"),
                .product(name: "SkipFoundation", package: "skip-foundation"),
            ],
            resources: [
                .process("Resources"),
            ],
            plugins: [
                .plugin(name: "skipstone", package: "skip")
            ]
        ),
        .testTarget(
            name: "M365AgentAppTests",
            dependencies: [
                "M365AgentApp",
                .product(name: "SkipTest", package: "skip-test")
            ],
            plugins: [
                .plugin(name: "skipstone", package: "skip")
            ]
        ),
    ]
)