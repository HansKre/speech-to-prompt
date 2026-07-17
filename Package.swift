// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SpeechToPrompt",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SpeechToPrompt", targets: ["SpeechToPrompt"])
    ],
    dependencies: [
        .package(name: "whisper.cpp", path: "./whisper.cpp")
    ],
    targets: [
        .executableTarget(
            name: "SpeechToPrompt",
            dependencies: [
                .product(name: "whisper", package: "whisper.cpp")
            ],
            path: "SpeechToPrompt",
            exclude: ["SpeechToPrompt.entitlements", "Assets.xcassets", "AppIcon.svg", "AppIcon.icns"]
        )
    ]
)
