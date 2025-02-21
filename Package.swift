// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FlashCompress",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "FlashCompress", targets: ["FlashCompress"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "FlashCompress",
            dependencies: [],
            exclude: ["Metal/Kernels.metal"],
            resources: [
                .copy("Resources/Metal")
            ],
            swiftSettings: [
                .define("METAL_ENABLED")
            ]
        ),
        .testTarget(
            name: "FlashCompressTests",
            dependencies: ["FlashCompress"]
        )
    ]
)
