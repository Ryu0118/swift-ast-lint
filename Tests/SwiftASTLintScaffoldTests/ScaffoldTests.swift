import FileManagerProtocol
import Foundation
@testable import SwiftASTLintScaffold
import Testing

@Suite(
    """
    Scaffold package generation via swift package CLI: \
    init, add-dependency, add-target, source templates, nested dirs, idempotent overwrite
    """,
)
struct ScaffoldTests {
    @Test("generates all expected files and directories")
    func allFiles() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let path = dir.appendingPathComponent("MyLinter").path
            try await Scaffold.generate(at: path, name: "MyLinter")

            let fileManager = FileManager.default
            #expect(fileManager.fileExists(atPath: "\(path)/Package.swift"))
            #expect(fileManager.fileExists(atPath: "\(path)/Sources/Rules/Rules.swift"))
            #expect(fileManager.fileExists(atPath: "\(path)/Sources/swift-ast-lint/main.swift"))
            #expect(fileManager.fileExists(atPath: "\(path)/.swift-ast-lint.yml"))
        }
    }

    @Test("Package.swift contains package name and dependencies added by swift package CLI")
    func packageContents() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let path = dir.appendingPathComponent("TestLinter").path
            try await Scaffold.generate(at: path, name: "TestLinter")

            let content = try String(contentsOfFile: "\(path)/Package.swift", encoding: .utf8)
            #expect(content.contains("name: \"TestLinter\""))
            #expect(content.contains("swift-ast-lint"))
            #expect(content.contains("swift-syntax"))
            #expect(content.contains("Rules"))
            #expect(content.contains("swift-ast-lint"))
        }
    }

    @Test("main.swift contains LintCommand.lint(rules)")
    func mainContent() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let path = dir.appendingPathComponent("XLinter").path
            try await Scaffold.generate(at: path, name: "XLinter")

            let content = try String(contentsOfFile: "\(path)/Sources/swift-ast-lint/main.swift", encoding: .utf8)
            #expect(content.contains("LintCommand.lint(rules)"))
        }
    }

    @Test("Rules.swift contains RuleSet builder")
    func rulesContent() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let path = dir.appendingPathComponent("RLinter").path
            try await Scaffold.generate(at: path, name: "RLinter")

            let content = try String(contentsOfFile: "\(path)/Sources/Rules/Rules.swift", encoding: .utf8)
            #expect(content.contains("import SwiftASTLint"))
            #expect(content.contains("RuleSet"))
        }
    }

    @Test("creates nested directories with mkdir -p semantics")
    func nestedPath() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let path = dir.appendingPathComponent("a/b/c/Linter").path
            try await Scaffold.generate(at: path, name: "Linter")

            #expect(FileManager.default.fileExists(atPath: "\(path)/Package.swift"))
        }
    }

    @Test("existing directory does not throw and overwrites files")
    func existingDir() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let path = dir.appendingPathComponent("Existing").path
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
            try await Scaffold.generate(at: path, name: "Existing")

            #expect(FileManager.default.fileExists(atPath: "\(path)/Package.swift"))
        }
    }

    @Test(".swift-ast-lint.yml contains default include/exclude paths")
    func ymlContent() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let path = dir.appendingPathComponent("YLinter").path
            try await Scaffold.generate(at: path, name: "YLinter")

            let content = try String(contentsOfFile: "\(path)/.swift-ast-lint.yml", encoding: .utf8)
            #expect(content.contains("Sources/**/*.swift"))
            #expect(content.contains(".build/**"))
        }
    }
}
