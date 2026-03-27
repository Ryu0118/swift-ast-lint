import FileManagerProtocol
import Foundation
import Subprocess
import System

/// Generates a new Swift Package configured as a linter project.
public struct Scaffold {
    private let fileManager: any FileManagerProtocol

    /// Creates a scaffold backed by the given file manager.
    public init(fileManager: some FileManagerProtocol = FileManager.default) {
        self.fileManager = fileManager
    }

    /// Generates a linter package at `path` with the given `name`.
    public func generate(at path: String, name: String) async throws {
        let resolvedPath = URL(filePath: path).standardized.path(percentEncoded: false)

        if !fileManager.fileExists(atPath: resolvedPath) {
            try fileManager.createDirectory(atPath: resolvedPath, withIntermediateDirectories: true)
        }

        // 1. swift package init --type empty
        try await runSwift(packagePath: resolvedPath, arguments: ["init", "--type", "empty", "--name", name])

        // 1.5. Add platforms (no CLI for this, so patch Package.swift directly)
        let packageSwiftPath = "\(resolvedPath)/Package.swift"
        let packageContent = try String(contentsOfFile: packageSwiftPath, encoding: .utf8)
        let patched = packageContent.replacingOccurrences(
            of: "name: \"\(name)\",",
            with: "name: \"\(name)\",\n    platforms: [.macOS(.v15)],",
        )
        try writeFile(content: patched, atPath: packageSwiftPath)

        // 2. Add dependencies
        try await runSwift(packagePath: resolvedPath, arguments: [
            "add-dependency",
            Constants.swiftASTLintURL,
            "--from", Constants.swiftASTLintMinVersion,
        ])
        try await runSwift(packagePath: resolvedPath, arguments: [
            "add-dependency",
            Constants.swiftSyntaxURL,
            "--from", Constants.swiftSyntaxMinVersion, "--to", Constants.swiftSyntaxMaxVersion,
        ])

        // 3. Add targets
        try await runSwift(packagePath: resolvedPath, arguments: [
            "add-target", Constants.rulesTarget, "--type", "library",
        ])
        try await runSwift(packagePath: resolvedPath, arguments: [
            "add-target", Constants.executableTarget,
            "--type", "executable", "--dependencies", Constants.rulesTarget,
        ])

        // 4. Add target dependencies (external products)
        try await runSwift(packagePath: resolvedPath, arguments: [
            "add-target-dependency",
            Constants.swiftASTLintProduct, Constants.rulesTarget,
            "--package", Constants.swiftASTLintPackage,
        ])
        try await runSwift(packagePath: resolvedPath, arguments: [
            "add-target-dependency",
            Constants.swiftSyntaxProduct, Constants.rulesTarget,
            "--package", Constants.swiftSyntaxPackage,
        ])

        // 5. Write source files
        try writeSourceFiles(at: resolvedPath)

        // 6. Write config
        try writeFile(content: Constants.ymlTemplate, atPath: "\(resolvedPath)/\(Constants.configFileName)")
    }

    // MARK: - Private

    private func runSwift(packagePath: String, arguments: [String]) async throws {
        let fullArguments = ["package", "--package-path", packagePath] + arguments
        let result = try await run(
            .name("swift"),
            arguments: Arguments(fullArguments),
            workingDirectory: FilePath(packagePath),
            output: .string(limit: 1024 * 1024),
            error: .string(limit: 1024 * 1024),
        )

        guard result.terminationStatus.isSuccess else {
            let errorOutput = result.standardError ?? ""
            throw ScaffoldError.commandFailed(
                command: "swift \(fullArguments.joined(separator: " "))",
                output: errorOutput,
            )
        }
    }

    private func writeSourceFiles(at path: String) throws {
        let dirs = [
            "\(path)/Sources/\(Constants.rulesTarget)",
            "\(path)/Sources/\(Constants.executableTarget)",
        ]
        for dir in dirs {
            try fileManager.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }

        let files: [(String, String)] = [
            ("Sources/\(Constants.executableTarget)/main.swift", Constants.mainSwift),
            ("Sources/\(Constants.rulesTarget)/Rules.swift", Constants.rulesSwift),
        ]
        for (subpath, content) in files {
            try writeFile(content: content, atPath: "\(path)/\(subpath)")
        }
    }

    private func writeFile(content: String, atPath path: String) throws {
        guard let data = content.data(using: .utf8) else {
            throw ScaffoldError.commandFailed(command: "write", output: "Failed to encode content to UTF-8")
        }
        _ = fileManager.createFile(atPath: path, contents: data)
    }
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
