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
            exclude: [
                "Metal/Kernels.air"
            ],
            resources: [
                .process("Resources"),
                .process("Metal", localization: nil)
            ]
        ),
        .testTarget(
            name: "FlashCompressTests",
            dependencies: ["FlashCompress"]
        )
    ]
)
