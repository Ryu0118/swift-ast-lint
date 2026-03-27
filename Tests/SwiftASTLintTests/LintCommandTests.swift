import FileManagerProtocol
import Foundation
@testable import SwiftASTLint
import SwiftParser
import SwiftSyntax
import Testing

// swiftlint:disable line_length force_unwrapping deep_nesting_control_flow

@Suite(
    """
    Linter end-to-end: file traversal, \
    intersection filtering (yml > RuleSet > Rule), sort order, and exit code mapping
    """,
)
struct LinterTests {
    @Test("lint single file with one rule producing warning")
    func singleWarning() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            try "let x = 1\n".write(to: dir.appendingPathComponent("a.swift"), atomically: true, encoding: .utf8)

            let rules = RuleSet {
                Rule(id: "always-warn", severity: .warning) { file, ctx in
                    ctx.report(on: file, message: "found code")
                }
            }
            let linter = LintEngine(rules: rules)
            let result = await linter.lint(paths: [dir.path(percentEncoded: false)])
            #expect(result.diagnostics.count == 1)
            #expect(result.diagnostics[0].severity == .warning)
            #expect(result.hasErrors == false)
        }
    }

    @Test("lint with error produces hasErrors = true")
    func hasErrors() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            try "let x = 1\n".write(to: dir.appendingPathComponent("a.swift"), atomically: true, encoding: .utf8)

            let rules = RuleSet {
                Rule(id: "always-err", severity: .error) { file, ctx in
                    ctx.report(on: file, message: "bad")
                }
            }
            let linter = LintEngine(rules: rules)
            let result = await linter.lint(paths: [dir.path(percentEncoded: false)])
            #expect(result.hasErrors == true)
        }
    }

    @Test("yml excluded_paths filters files")
    func ymlExclude() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let fileManager = FileManager.default
            try fileManager.createDirectory(
                at: dir.appendingPathComponent("Sources"),
                withIntermediateDirectories: true,
            )
            try fileManager.createDirectory(
                at: dir.appendingPathComponent("Generated"),
                withIntermediateDirectories: true,
            )
            try "let a = 1\n".write(to: dir.appendingPathComponent("Sources/a.swift"), atomically: true, encoding: .utf8)
            try "let b = 2\n".write(to: dir.appendingPathComponent("Generated/b.swift"), atomically: true, encoding: .utf8)

            let config = Configuration(excludedPaths: ["Generated/**"])
            let rules = RuleSet {
                Rule(id: "count", severity: .warning) { file, ctx in
                    ctx.report(on: file, message: "found")
                }
            }
            let linter = LintEngine(rules: rules, config: config)
            let result = await linter.lint(paths: [dir.path(percentEncoded: false)])
            #expect(result.diagnostics.count == 1)
            #expect(result.diagnostics[0].filePath.contains("Sources"))
        }
    }

    @Test("Rule-level include restricts to specific files")
    func ruleInclude() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let fileManager = FileManager.default
            try fileManager.createDirectory(
                at: dir.appendingPathComponent("Sources"),
                withIntermediateDirectories: true,
            )
            try fileManager.createDirectory(
                at: dir.appendingPathComponent("Tests"),
                withIntermediateDirectories: true,
            )
            try "let a = 1\n".write(to: dir.appendingPathComponent("Sources/a.swift"), atomically: true, encoding: .utf8)
            try "let b = 2\n".write(to: dir.appendingPathComponent("Tests/b.swift"), atomically: true, encoding: .utf8)

            let rules = RuleSet {
                Rule(id: "sources-only", severity: .warning, include: ["Sources/**"]) { file, ctx in
                    ctx.report(on: file, message: "found")
                }
            }
            let linter = LintEngine(rules: rules)
            let result = await linter.lint(paths: [dir.path(percentEncoded: false)])
            #expect(result.diagnostics.count == 1)
        }
    }

    @Test("diagnostics sorted by file path then line")
    func sortOrder() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            try "let x = 1\nlet y = 2\n".write(to: dir.appendingPathComponent("b.swift"), atomically: true, encoding: .utf8)
            try "let z = 3\n".write(to: dir.appendingPathComponent("a.swift"), atomically: true, encoding: .utf8)

            let rules = RuleSet {
                Rule(id: "all", severity: .warning) { file, ctx in
                    for stmt in file.statements {
                        ctx.report(on: stmt, message: "found")
                    }
                }
            }
            let linter = LintEngine(rules: rules)
            let result = await linter.lint(paths: [dir.path(percentEncoded: false)])
            let paths = result.diagnostics.map(\.filePath)
            #expect(paths.first!.hasSuffix("a.swift"))
        }
    }

    @Test("no swift files produces empty diagnostics")
    func noFiles() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let rules = RuleSet {
                Rule(id: "x", severity: .warning) { _, ctx in
                    ctx.report(on: Parser.parse(source: ""), message: "never")
                }
            }
            let linter = LintEngine(rules: rules)
            let result = await linter.lint(paths: [dir.path(percentEncoded: false)])
            #expect(result.diagnostics.isEmpty)
        }
    }

    @Test("RuleSet globalInclude restricts file universe")
    func ruleSetGlobalInclude() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let fileManager = FileManager.default
            try fileManager.createDirectory(
                at: dir.appendingPathComponent("Sources"),
                withIntermediateDirectories: true,
            )
            try fileManager.createDirectory(
                at: dir.appendingPathComponent("Tests"),
                withIntermediateDirectories: true,
            )
            try "let a = 1\n".write(to: dir.appendingPathComponent("Sources/a.swift"), atomically: true, encoding: .utf8)
            try "let b = 2\n".write(to: dir.appendingPathComponent("Tests/b.swift"), atomically: true, encoding: .utf8)

            let rules = RuleSet {
                Rule(id: "all", severity: .warning) { file, ctx in
                    ctx.report(on: file, message: "found")
                }
            }.include(["Sources/**"])
            let linter = LintEngine(rules: rules)
            let result = await linter.lint(paths: [dir.path(percentEncoded: false)])
            #expect(result.diagnostics.count == 1)
            #expect(result.diagnostics[0].filePath.contains("Sources"))
        }
    }

    @Test("RuleSet globalExclude removes files")
    func ruleSetGlobalExclude() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            try "let a = 1\n".write(to: dir.appendingPathComponent("keep.swift"), atomically: true, encoding: .utf8)
            try "let b = 2\n".write(to: dir.appendingPathComponent("skip_Generated.swift"), atomically: true, encoding: .utf8)

            let rules = RuleSet {
                Rule(id: "all", severity: .warning) { file, ctx in
                    ctx.report(on: file, message: "found")
                }
            }.exclude(["**/*Generated.swift"])
            let linter = LintEngine(rules: rules)
            let result = await linter.lint(paths: [dir.path(percentEncoded: false)])
            #expect(result.diagnostics.count == 1)
            #expect(result.diagnostics[0].filePath.contains("keep"))
        }
    }

    @Test("exit code mapping", arguments: [
        (Severity.warning, false),
        (Severity.error, true),
    ])
    func exitCodeMapping(severity: Severity, expectedHasErrors: Bool) async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            try "let x = 1\n".write(to: dir.appendingPathComponent("a.swift"), atomically: true, encoding: .utf8)

            let rules = RuleSet {
                Rule(id: "r", severity: severity) { file, ctx in
                    ctx.report(on: file, message: "msg")
                }
            }
            let linter = LintEngine(rules: rules)
            let result = await linter.lint(paths: [dir.path(percentEncoded: false)])
            #expect(result.hasErrors == expectedHasErrors)
        }
    }

    @Test("three-layer intersection: yml include + RuleSet exclude + Rule include")
    func threeLayerIntersection() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let fileManager = FileManager.default
            try fileManager.createDirectory(at: dir.appendingPathComponent("Sources/Core"), withIntermediateDirectories: true)
            try fileManager.createDirectory(at: dir.appendingPathComponent("Sources/Generated"), withIntermediateDirectories: true)
            try fileManager.createDirectory(at: dir.appendingPathComponent("Tests"), withIntermediateDirectories: true)

            try "let a = 1\n".write(to: dir.appendingPathComponent("Sources/Core/a.swift"), atomically: true, encoding: .utf8)
            try "let b = 2\n".write(to: dir.appendingPathComponent("Sources/Generated/b.swift"), atomically: true, encoding: .utf8)
            try "let c = 3\n".write(to: dir.appendingPathComponent("Tests/c.swift"), atomically: true, encoding: .utf8)

            // yml: only Sources/**
            let config = Configuration(
                includedPaths: ["Sources/**/*.swift"],
            )
            // RuleSet: exclude Generated
            // Rule: include only Core
            let rules = RuleSet {
                Rule(
                    id: "core-only",
                    severity: .warning,
                    include: ["Sources/Core/**"],
                ) { file, ctx in
                    ctx.report(on: file, message: "found")
                }
            }.exclude(["Sources/Generated/**"])

            let linter = LintEngine(rules: rules, config: config)
            let result = await linter.lint(paths: [dir.path(percentEncoded: false)])
            // Only Sources/Core/a.swift should survive all 3 layers
            #expect(result.diagnostics.count == 1)
            #expect(result.diagnostics[0].filePath.contains("Core/a.swift"))
        }
    }
}

// swiftlint:enable line_length force_unwrapping deep_nesting_control_flow
