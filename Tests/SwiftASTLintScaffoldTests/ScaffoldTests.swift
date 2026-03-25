import Testing
import Foundation
import FileManagerProtocol
@testable import SwiftASTLintScaffold

@Suite("Scaffold")
struct ScaffoldTests {
    @Test("generates all expected files")
    func allFiles() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let path = dir.appendingPathComponent("MyLinter").path
            try Scaffold.generate(at: path, name: "MyLinter")

            let fm = FileManager.default
            #expect(fm.fileExists(atPath: "\(path)/Package.swift"))
            #expect(fm.fileExists(atPath: "\(path)/Sources/Rules/Rules.swift"))
            #expect(fm.fileExists(atPath: "\(path)/Sources/swift-ast-lint/main.swift"))
            #expect(fm.fileExists(atPath: "\(path)/.swift-ast-lint.yml"))
        }
    }

    @Test("Package.swift contains correct name")
    func packageName() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let path = dir.appendingPathComponent("TestLinter").path
            try Scaffold.generate(at: path, name: "TestLinter")

            let content = try String(contentsOfFile: "\(path)/Package.swift", encoding: .utf8)
            #expect(content.contains("name: \"TestLinter\""))
        }
    }

    @Test("main.swift contains LintCommand.lint(rules)")
    func mainContent() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let path = dir.appendingPathComponent("X").path
            try Scaffold.generate(at: path, name: "X")

            let content = try String(contentsOfFile: "\(path)/Sources/swift-ast-lint/main.swift", encoding: .utf8)
            #expect(content.contains("LintCommand.lint(rules)"))
        }
    }

    @Test("creates nested directories")
    func nestedPath() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let path = dir.appendingPathComponent("a/b/c/Linter").path
            try Scaffold.generate(at: path, name: "Linter")

            #expect(FileManager.default.fileExists(atPath: "\(path)/Package.swift"))
        }
    }

    @Test("existing directory does not throw")
    func existingDir() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let path = dir.appendingPathComponent("Existing").path
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
            try Scaffold.generate(at: path, name: "Existing")

            #expect(FileManager.default.fileExists(atPath: "\(path)/Package.swift"))
        }
    }
}
