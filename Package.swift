// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Marky",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "Marky",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/MarkdownEditor",
            resources: [
                .copy("WebView/Resources"),
                .copy("App/AppIcon.icns")
            ]
        )
    ]
)
