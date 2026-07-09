// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Selah",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "Selah", targets: ["Selah"]),
    ],
    targets: [
        .target(
            name: "Selah",
            path: "Selah",
            exclude: [
                // Exclude subdirectory files that are accessed via the flat include
            ]
        ),
        .testTarget(
            name: "SelahTests",
            dependencies: ["Selah"],
            path: "SelahTests"
        ),
    ]
)
