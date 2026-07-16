// swift-tools-version:6.0
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
                "PrivacyInfo.xcprivacy",
                "Selah.entitlements",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "SelahTests",
            dependencies: ["Selah"],
            path: "SelahTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
    ]
)
