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
        .package(url: "https://github.com/swift-molecules/swift-acoustics-plate.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-acoustics-resonator.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-acoustics-striker.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-contact.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-acceleration.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-decay.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-frequency.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-loss.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-mass.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-modulus.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-numeric.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-strain.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-pressure.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-stress.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-threefry.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Acoustics Fracture",
            dependencies: [
                .product(name: "Acoustics", package: "swift-acoustics"),
                .product(name: "Acoustics Plate", package: "swift-acoustics-plate"),
                .product(name: "Acoustics Resonator", package: "swift-acoustics-resonator"),
                .product(name: "Acoustics Striker", package: "swift-acoustics-striker"),
                .product(name: "Contact", package: "swift-contact"),
                .product(name: "Acceleration", package: "swift-acceleration"),
                .product(name: "Decay", package: "swift-decay"),
                .product(name: "Frequency", package: "swift-frequency"),
                .product(name: "Loss", package: "swift-loss"),
                .product(name: "Mass", package: "swift-mass"),
                .product(name: "Modulus", package: "swift-modulus"),
                .product(name: "Numeric", package: "swift-numeric"),
                .product(name: "Strain", package: "swift-strain"),
                .product(name: "Pressure", package: "swift-pressure"),
                .product(name: "Stress", package: "swift-stress"),
                .product(name: "Threefry", package: "swift-threefry"),
            ]
        ),
        .testTarget(
            name: "Acoustics Fracture Tests",
            dependencies: [
                .target(name: "Acoustics Fracture"),
                .product(name: "Numeric", package: "swift-numeric"),
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
