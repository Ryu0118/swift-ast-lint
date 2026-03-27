// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-ast-linter",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0" ..< "700.0.0"),
    ],
    targets: [
        .target(name: "Rules", dependencies: [
            .product(name: "SwiftASTLint", package: "swift-ast-lint"),
            .product(name: "SwiftSyntax", package: "swift-syntax"),
        ]),
        .executableTarget(
            name: "swift-ast-lint",
            dependencies: ["Rules"],
        ),
    ],
)
