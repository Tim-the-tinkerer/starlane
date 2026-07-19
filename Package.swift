// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Starlane",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Starlane", targets: ["Starlane"]),
    ],
    targets: [
        .executableTarget(
            name: "Starlane",
            path: "Sources/Starlane"
        ),
    ]
)
