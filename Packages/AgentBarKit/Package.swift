// swift-tools-version: 6.2
import PackageDescription

// Everything that is not UI: models, readers, the snapshot codec. The app target, the widget
// extension and the tests all depend on it, and `swift test` runs it headless.
let package = Package(
    name: "AgentBarKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AgentBarKit", targets: ["AgentBarKit"]),
    ],
    targets: [
        .target(
            name: "AgentBarKit",
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ]
        ),
        .testTarget(
            name: "AgentBarKitTests",
            dependencies: ["AgentBarKit"],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
