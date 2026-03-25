// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-ast-lint",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SwiftASTLint", targets: ["SwiftASTLint"]),
        .library(name: "SwiftASTLintScaffold", targets: ["SwiftASTLintScaffold"]),
        .executable(name: "swiftastlinttool", targets: ["swift-ast-lint-tool"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "SwiftASTLint",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "Yams", package: "Yams"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "SwiftASTLintScaffold"
        ),
        .executableTarget(
            name: "swift-ast-lint-tool",
            dependencies: [
                "SwiftASTLintScaffold",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "SwiftASTLintTests",
            dependencies: [
                "SwiftASTLint",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "SwiftASTLintScaffoldTests",
            dependencies: ["SwiftASTLintScaffold"]
        ),
    ]
)
