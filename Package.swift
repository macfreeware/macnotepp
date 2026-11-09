// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MacNotePP",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacNotePP", targets: ["MacNotePP"])
    ],
    targets: [
        .executableTarget(
            name: "MacNotePP",
            path: "Sources/MacNotePP"
        )
    ]
)
