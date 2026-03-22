// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ShadowVoiceClientCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "ShadowVoiceClientCore",
            targets: ["ShadowVoiceClientCore"]
        ),
    ],
    targets: [
        .target(
            name: "ShadowVoiceClientCore"
        ),
        .testTarget(
            name: "ShadowVoiceClientCoreTests",
            dependencies: ["ShadowVoiceClientCore"]
        ),
    ]
)
