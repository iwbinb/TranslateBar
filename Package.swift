// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TranslateBar",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "TranslateBar", targets: ["TranslateBar"])
    ],
    targets: [
        .executableTarget(
            name: "TranslateBar",
            path: "Sources/TranslateBar"
        ),
        .testTarget(
            name: "TranslateBarTests",
            dependencies: ["TranslateBar"],
            path: "Tests/TranslateBarTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
