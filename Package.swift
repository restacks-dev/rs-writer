// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WriterCore", platforms: [.macOS(.v14)],
    products: [.library(name: "WriterCore", targets: ["WriterCore"])],
    targets: [
        .target(name: "WriterCore", path: "Sources/WriterCore"),
        .testTarget(name: "WriterCoreTests", dependencies: ["WriterCore"], path: "Tests")
    ]
)
