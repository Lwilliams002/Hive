// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HiveCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "HiveCore", targets: ["HiveCore"])
    ],
    targets: [
        .target(name: "HiveCore"),
        .testTarget(
            name: "HiveCoreTests",
            dependencies: ["HiveCore"],
            resources: [.copy("Fixtures")]
        )
    ],
    swiftLanguageVersions: [.v5]
)
