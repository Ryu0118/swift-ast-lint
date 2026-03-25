import Testing
import SwiftSyntax
import SwiftParser
import Foundation
@testable import SwiftASTLint

@Suite("LintCommand")
struct LintCommandTests {
    private func tempDir() throws -> String {
        let dir = NSTemporaryDirectory() + "swift-ast-lint-test-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("lint single file with one rule producing warning")
    func singleWarning() async throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        try "let x = 1\n".write(toFile: "\(dir)/a.swift", atomically: true, encoding: .utf8)

        let rules = RuleSet {
            Rule(id: "always-warn", severity: .warning) { file, ctx in
                ctx.report(on: file, message: "found code")
            }
        }
        let result = try await LintCommand.lintFiles(rules: rules, config: nil, rootPath: dir)
        #expect(result.diagnostics.count == 1)
        #expect(result.diagnostics[0].severity == .warning)
        #expect(result.hasErrors == false)
    }

    @Test("lint with error produces hasErrors = true")
    func hasErrors() async throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        try "let x = 1\n".write(toFile: "\(dir)/a.swift", atomically: true, encoding: .utf8)

        let rules = RuleSet {
            Rule(id: "always-err", severity: .error) { file, ctx in
                ctx.report(on: file, message: "bad")
            }
        }
        let result = try await LintCommand.lintFiles(rules: rules, config: nil, rootPath: dir)
        #expect(result.hasErrors == true)
    }

    @Test("yml excluded_paths filters files")
    func ymlExclude() async throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        try FileManager.default.createDirectory(atPath: "\(dir)/Sources", withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: "\(dir)/Generated", withIntermediateDirectories: true)
        try "let a = 1\n".write(toFile: "\(dir)/Sources/a.swift", atomically: true, encoding: .utf8)
        try "let b = 2\n".write(toFile: "\(dir)/Generated/b.swift", atomically: true, encoding: .utf8)

        let config = Configuration(excludedPaths: ["Generated/**"])
        let rules = RuleSet {
            Rule(id: "count", severity: .warning) { file, ctx in
                ctx.report(on: file, message: "found")
            }
        }
        let result = try await LintCommand.lintFiles(rules: rules, config: config, rootPath: dir)
        #expect(result.diagnostics.count == 1)
        #expect(result.diagnostics[0].filePath.contains("Sources"))
    }

    @Test("Rule-level include restricts to specific files")
    func ruleInclude() async throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        try FileManager.default.createDirectory(atPath: "\(dir)/Sources", withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: "\(dir)/Tests", withIntermediateDirectories: true)
        try "let a = 1\n".write(toFile: "\(dir)/Sources/a.swift", atomically: true, encoding: .utf8)
        try "let b = 2\n".write(toFile: "\(dir)/Tests/b.swift", atomically: true, encoding: .utf8)

        let rules = RuleSet {
            Rule(id: "sources-only", severity: .warning, include: ["Sources/**"]) { file, ctx in
                ctx.report(on: file, message: "found")
            }
        }
        let result = try await LintCommand.lintFiles(rules: rules, config: nil, rootPath: dir)
        #expect(result.diagnostics.count == 1)
    }

    @Test("diagnostics sorted by file path then line")
    func sortOrder() async throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        try "let x = 1\nlet y = 2\n".write(toFile: "\(dir)/b.swift", atomically: true, encoding: .utf8)
        try "let z = 3\n".write(toFile: "\(dir)/a.swift", atomically: true, encoding: .utf8)

        let rules = RuleSet {
            Rule(id: "all", severity: .warning) { file, ctx in
                for stmt in file.statements {
                    ctx.report(on: stmt, message: "found")
                }
            }
        }
        let result = try await LintCommand.lintFiles(rules: rules, config: nil, rootPath: dir)
        let paths = result.diagnostics.map(\.filePath)
        #expect(paths.first!.hasSuffix("a.swift"))
    }

    @Test("no swift files produces empty diagnostics")
    func noFiles() async throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let rules = RuleSet {
            Rule(id: "x", severity: .warning) { _, ctx in
                ctx.report(on: Parser.parse(source: ""), message: "never")
            }
        }
        let result = try await LintCommand.lintFiles(rules: rules, config: nil, rootPath: dir)
        #expect(result.diagnostics.isEmpty)
    }

    @Test("RuleSet globalInclude restricts file universe")
    func ruleSetGlobalInclude() async throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        try FileManager.default.createDirectory(atPath: "\(dir)/Sources", withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: "\(dir)/Tests", withIntermediateDirectories: true)
        try "let a = 1\n".write(toFile: "\(dir)/Sources/a.swift", atomically: true, encoding: .utf8)
        try "let b = 2\n".write(toFile: "\(dir)/Tests/b.swift", atomically: true, encoding: .utf8)

        let rules = RuleSet {
            Rule(id: "all", severity: .warning) { file, ctx in
                ctx.report(on: file, message: "found")
            }
        }.include(["Sources/**"])
        let result = try await LintCommand.lintFiles(rules: rules, config: nil, rootPath: dir)
        #expect(result.diagnostics.count == 1)
        #expect(result.diagnostics[0].filePath.contains("Sources"))
    }

    @Test("RuleSet globalExclude removes files")
    func ruleSetGlobalExclude() async throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        try "let a = 1\n".write(toFile: "\(dir)/keep.swift", atomically: true, encoding: .utf8)
        try "let b = 2\n".write(toFile: "\(dir)/skip_Generated.swift", atomically: true, encoding: .utf8)

        let rules = RuleSet {
            Rule(id: "all", severity: .warning) { file, ctx in
                ctx.report(on: file, message: "found")
            }
        }.exclude(["**/*Generated.swift"])
        let result = try await LintCommand.lintFiles(rules: rules, config: nil, rootPath: dir)
        #expect(result.diagnostics.count == 1)
        #expect(result.diagnostics[0].filePath.contains("keep"))
    }

    @Test("exit code mapping", arguments: [
        (Severity.warning, false),
        (Severity.error, true),
    ])
    func exitCodeMapping(severity: Severity, expectedHasErrors: Bool) async throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(atPath: dir) }
        try "let x = 1\n".write(toFile: "\(dir)/a.swift", atomically: true, encoding: .utf8)

        let rules = RuleSet {
            Rule(id: "r", severity: severity) { file, ctx in
                ctx.report(on: file, message: "msg")
            }
        }
        let result = try await LintCommand.lintFiles(rules: rules, config: nil, rootPath: dir)
        #expect(result.hasErrors == expectedHasErrors)
    }
}
