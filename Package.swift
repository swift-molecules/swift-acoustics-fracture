// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-acoustics-fracture",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(name: "Acoustics Fracture", targets: ["Acoustics Fracture"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-molecules/swift-acoustics.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Acoustics Fracture",
            dependencies: [
                .product(name: "Acoustics", package: "swift-acoustics"),
            ]
        ),
        .testTarget(
            name: "Acoustics Fracture Tests",
            dependencies: [
                .target(name: "Acoustics Fracture")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings =
        (target.swiftSettings ?? []) + [
            .strictMemorySafety(),
            .enableUpcomingFeature("ExistentialAny"),
            .enableUpcomingFeature("InternalImportsByDefault"),
            .enableUpcomingFeature("MemberImportVisibility"),
            .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            .enableUpcomingFeature("InferIsolatedConformances"),
            .enableExperimentalFeature("Lifetimes"),
            .treatAllWarnings(as: .error),
        ]
}
