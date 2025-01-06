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
    dependencies: [
        // Add dependencies here as needed
    ],
    targets: [
        .executableTarget(
            name: "FlashCompress",
            dependencies: [],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "FlashCompressTests",
            dependencies: ["FlashCompress"]
        )
    ]
)
