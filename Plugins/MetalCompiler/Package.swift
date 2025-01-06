// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "metal-compiler",
    products: [
        .plugin(
            name: "MetalCompiler",
            targets: ["MetalCompiler"]
        )
    ],
    targets: [
        .plugin(
            name: "MetalCompiler",
            capability: .buildTool()
        )
    ]
)
