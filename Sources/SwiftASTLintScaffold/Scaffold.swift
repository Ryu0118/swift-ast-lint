import Foundation

public struct Scaffold {
    public static func generate(at path: String, name: String) throws {
        let fm = FileManager.default

        // Create parent directories if needed
        let parentDir = (path as NSString).deletingLastPathComponent
        if !parentDir.isEmpty {
            try fm.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
        }

        // Run swift package init --type empty
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["package", "init", "--type", "empty", "--name", name]
        process.currentDirectoryURL = URL(fileURLWithPath: parentDir.isEmpty ? "." : parentDir)

        // If the target directory doesn't exist yet, create it first
        if !fm.fileExists(atPath: path) {
            try fm.createDirectory(atPath: path, withIntermediateDirectories: true)
        }
        process.currentDirectoryURL = URL(fileURLWithPath: path)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw ScaffoldError.packageInitFailed(output)
        }

        // Create additional directories
        let dirs = [
            "\(path)/Sources/Rules",
            "\(path)/Sources/swift-ast-lint",
        ]
        for dir in dirs {
            try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }

        // Overwrite Package.swift with our template
        try packageSwift(name: name).write(
            toFile: "\(path)/Package.swift", atomically: true, encoding: .utf8
        )
        try mainSwift.write(
            toFile: "\(path)/Sources/swift-ast-lint/main.swift", atomically: true, encoding: .utf8
        )
        try rulesSwift.write(
            toFile: "\(path)/Sources/Rules/Rules.swift", atomically: true, encoding: .utf8
        )
        try ymlTemplate.write(
            toFile: "\(path)/.swift-ast-lint.yml", atomically: true, encoding: .utf8
        )
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
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
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
        case .packageInitFailed(let output):
            return "swift package init failed: \(output)"
        }
    }
}
