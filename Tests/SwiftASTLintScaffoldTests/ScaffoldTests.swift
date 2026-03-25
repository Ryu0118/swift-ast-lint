import Testing
import Foundation
@testable import SwiftASTLintScaffold

@Suite("Scaffold")
struct ScaffoldTests {
    private func tempDir() throws -> String {
        let dir = NSTemporaryDirectory() + "scaffold-test-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("generates all expected files")
    func allFiles() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let path = "\(dir)/MyLinter"
        try Scaffold.generate(at: path, name: "MyLinter")

        let fm = FileManager.default
        #expect(fm.fileExists(atPath: "\(path)/Package.swift"))
        #expect(fm.fileExists(atPath: "\(path)/Sources/Rules/Rules.swift"))
        #expect(fm.fileExists(atPath: "\(path)/Sources/swift-ast-lint/main.swift"))
        #expect(fm.fileExists(atPath: "\(path)/.swift-ast-lint.yml"))
    }

    @Test("Package.swift contains correct name")
    func packageName() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let path = "\(dir)/TestLinter"
        try Scaffold.generate(at: path, name: "TestLinter")

        let content = try String(contentsOfFile: "\(path)/Package.swift", encoding: .utf8)
        #expect(content.contains("name: \"TestLinter\""))
    }

    @Test("main.swift contains LintCommand.lint(rules)")
    func mainContent() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let path = "\(dir)/X"
        try Scaffold.generate(at: path, name: "X")

        let content = try String(contentsOfFile: "\(path)/Sources/swift-ast-lint/main.swift", encoding: .utf8)
        #expect(content.contains("LintCommand.lint(rules)"))
    }

    @Test("creates nested directories")
    func nestedPath() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let path = "\(dir)/a/b/c/Linter"
        try Scaffold.generate(at: path, name: "Linter")

        #expect(FileManager.default.fileExists(atPath: "\(path)/Package.swift"))
    }

    @Test("existing directory does not throw")
    func existingDir() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let path = "\(dir)/Existing"
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        try Scaffold.generate(at: path, name: "Existing")

        #expect(FileManager.default.fileExists(atPath: "\(path)/Package.swift"))
    }
}
