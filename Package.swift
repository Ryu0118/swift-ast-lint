// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-ast-lint",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "SwiftASTLint", targets: ["SwiftASTLint"]),
        .library(name: "SwiftASTLintTestSupport", targets: ["SwiftASTLintTestSupport"]),
        .library(name: "SwiftASTLintScaffold", targets: ["SwiftASTLintScaffold"]),
        .executable(name: "swiftastlinttool", targets: ["swift-ast-lint-tool"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0" ..< "700.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.7.1"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.1"),
        .package(url: "https://github.com/Ryu0118/FileManagerProtocol.git", from: "0.1.0"),
        .package(url: "https://github.com/swiftlang/swift-subprocess.git", from: "0.4.0"),
        .package(url: "https://github.com/mtj0928/swift-async-operations.git", from: "0.5.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.2"),
    ],
    targets: [
        .target(
            name: "SwiftASTLint",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                .product(name: "Yams", package: "Yams"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "AsyncOperations", package: "swift-async-operations"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "FileManagerProtocol", package: "FileManagerProtocol"),
            ],
        ),
        .target(
            name: "SwiftASTLintTestSupport",
            dependencies: [
                "SwiftASTLint",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
            ],
        ),
        .target(
            name: "SwiftASTLintScaffold",
            dependencies: [
                .product(name: "Subprocess", package: "swift-subprocess"),
                .product(name: "FileManagerProtocol", package: "FileManagerProtocol"),
            ],
        ),
        .executableTarget(
            name: "swift-ast-lint-tool",
            dependencies: [
                "SwiftASTLintScaffold",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
            ],
        ),
        .testTarget(
            name: "SwiftASTLintTests",
            dependencies: [
                "SwiftASTLint",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "FileManagerProtocol", package: "FileManagerProtocol"),
            ],
        ),
        .testTarget(
            name: "SwiftASTLintScaffoldTests",
            dependencies: [
                "SwiftASTLintScaffold",
                .product(name: "FileManagerProtocol", package: "FileManagerProtocol"),
            ],
        ),
    ],
)
