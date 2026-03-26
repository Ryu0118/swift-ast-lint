import Foundation
import Subprocess
import System

public enum Scaffold {
    public static func generate(at path: String, name: String) async throws {
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: path) {
            try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
        }

        // 1. swift package init --type empty
        try await runSwift(at: path, arguments: ["package", "init", "--type", "empty", "--name", name])

        // 2. Add dependencies
        try await runSwift(at: path, arguments: [
            "package", "add-dependency",
            "https://github.com/Ryu0118/swift-ast-lint.git",
            "--from", "0.1.0",
        ])
        try await runSwift(at: path, arguments: [
            "package", "add-dependency",
            "https://github.com/swiftlang/swift-syntax.git",
            "--from", "602.0.0",
        ])

        // 3. Add targets
        try await runSwift(at: path, arguments: [
            "package", "add-target", "Rules", "--type", "library",
        ])
        try await runSwift(at: path, arguments: [
            "package", "add-target", "swift-ast-lint",
            "--type", "executable", "--dependencies", "Rules",
        ])

        // 4. Add target dependencies (external products)
        try await runSwift(at: path, arguments: [
            "package", "add-target-dependency",
            "SwiftASTLint", "Rules", "--package", "swift-ast-lint",
        ])
        try await runSwift(at: path, arguments: [
            "package", "add-target-dependency",
            "SwiftSyntax", "Rules", "--package", "swift-syntax",
        ])

        // 5. Write source files
        try writeSourceFiles(at: path)

        // 6. Write config
        try ymlTemplate.write(
            toFile: "\(path)/.swift-ast-lint.yml",
            atomically: true,
            encoding: .utf8,
        )
    }

    // MARK: - Private

    private static func runSwift(at path: String, arguments: [String]) async throws {
        let result = try await run(
            .name("swift"),
            arguments: Arguments(arguments),
            workingDirectory: FilePath(path),
            output: .string(limit: 1024 * 1024),
            error: .string(limit: 1024 * 1024),
        )

        guard result.terminationStatus.isSuccess else {
            let errorOutput = result.standardError ?? ""
            throw ScaffoldError.commandFailed(
                command: "swift \(arguments.joined(separator: " "))",
                output: errorOutput,
            )
        }
    }

    private static func writeSourceFiles(at path: String) throws {
        let fileManager = FileManager.default
        let dirs = [
            "\(path)/Sources/Rules",
            "\(path)/Sources/swift-ast-lint",
        ]
        for dir in dirs {
            try fileManager.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }

        let files: [(String, String)] = [
            ("Sources/swift-ast-lint/main.swift", mainSwift),
            ("Sources/Rules/Rules.swift", rulesSwift),
        ]
        for (subpath, content) in files {
            try content.write(
                toFile: "\(path)/\(subpath)",
                atomically: true,
                encoding: .utf8,
            )
        }
    }

    // MARK: - Templates (source files only, not Package.swift)

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
    case commandFailed(command: String, output: String)

    public var description: String {
        switch self {
        case let .commandFailed(command, output):
            "\(command) failed: \(output)"
        }
    }
}
