// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Atmosphere",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Atmosphere", targets: ["Atmosphere"])
    ],
    targets: [
        .executableTarget(
            name: "Atmosphere"
        ),
        .testTarget(
            name: "AtmosphereTests",
            dependencies: ["Atmosphere"]
        )
    ]
)
