// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RadioNaoufal",
    defaultLocalization: "nl",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "RadioNaoufal", targets: ["RadioNaoufal"])
    ],
    dependencies: [
        .package(url: "https://github.com/dioKaratzas/swift-chromecast-kit", exact: "1.0.1")
    ],
    targets: [
        .executableTarget(
            name: "RadioNaoufal",
            dependencies: [
                .product(name: "ChromecastKit", package: "swift-chromecast-kit")
            ],
            path: "RadioNaoufal",
            exclude: [
                "Info.plist",
                "RadioNaoufal.entitlements"
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableUpcomingFeature("ExistentialAny"),
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "RadioNaoufalTests",
            dependencies: ["RadioNaoufal"],
            path: "RadioNaoufalTests"
        )
    ]
)
