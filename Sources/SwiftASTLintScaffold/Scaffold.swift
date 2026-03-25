import Foundation
import Subprocess
import System

public enum Scaffold {
    public static func generate(at path: String, name: String) async throws {
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: path) {
            try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
        }

        try await runSwiftPackageInit(at: path, name: name)
        try createSourceDirectories(at: path)
        try writeTemplates(at: path, name: name)
    }

    // MARK: - Steps

    private static func runSwiftPackageInit(at path: String, name: String) async throws {
        let result = try await run(
            .name("swift"),
            arguments: ["package", "init", "--type", "empty", "--name", name],
            workingDirectory: FilePath(path),
            output: .string(limit: 1024 * 1024),
            error: .string(limit: 1024 * 1024),
        )

        guard result.terminationStatus.isSuccess else {
            let errorOutput = result.standardError ?? ""
            throw ScaffoldError.packageInitFailed(errorOutput)
        }
    }

    private static func createSourceDirectories(at path: String) throws {
        let fileManager = FileManager.default
        let dirs = [
            "\(path)/Sources/Rules",
            "\(path)/Sources/swift-ast-lint",
        ]
        for dir in dirs {
            try fileManager.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }
    }

    private static func writeTemplates(at path: String, name: String) throws {
        let files: [(String, String)] = [
            ("Package.swift", packageSwift(name: name)),
            ("Sources/swift-ast-lint/main.swift", mainSwift),
            ("Sources/Rules/Rules.swift", rulesSwift),
            (".swift-ast-lint.yml", ymlTemplate),
        ]
        for (subpath, content) in files {
            try content.write(
                toFile: "\(path)/\(subpath)",
                atomically: true,
                encoding: .utf8,
            )
        }
    }

    // MARK: - Templates

    private static func packageSwift(name: String) -> String {
        """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "\(name)",
            platforms: [.macOS(.v13)],
            dependencies: [
                // TODO: Update to actual repository URL
                .package(url: "https://github.com/aspect-build/swift-ast-lint.git", from: "0.1.0"),
                .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0"),
            ],
            targets: [
                .target(
                    name: "Rules",
                    dependencies: [
                        .product(name: "SwiftASTLint", package: "swift-ast-lint"),
                        .product(name: "SwiftSyntax", package: "swift-syntax"),
                    ]
                ),
                .executableTarget(
                    name: "swift-ast-lint",
                    dependencies: ["Rules"]
                ),
            ]
        )
        """
    }

    private static let mainSwift =
        """
        import SwiftASTLint
        import Rules

        LintCommand.lint(rules)
        """

    private static let rulesSwift =
        """
        import SwiftASTLint
        import SwiftSyntax

        public let rules = RuleSet {
            // Add your rules here
        }
        """

    private static let ymlTemplate =
        """
        included_paths:
          - "Sources/**/*.swift"
        excluded_paths:
          - ".build/**"
        """
}

public enum ScaffoldError: Error, CustomStringConvertible {
    case packageInitFailed(String)

    public var description: String {
        switch self {
        case let .packageInitFailed(output):
            "swift package init failed: \(output)"
        }
    }
}
