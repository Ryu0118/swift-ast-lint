import FileManagerProtocol
import Foundation
@testable import SwiftASTLint
import SwiftParser
import SwiftSyntax
import Testing

// swiftlint:disable line_length force_unwrapping deep_nesting_control_flow

@Suite(
    """
    LintEngine end-to-end: file traversal, \
    intersection filtering (yml > RuleSet > Rule), sort order, and exit code mapping
    """,
)
struct LinterTests {
    @Test("lint single file with one rule producing warning")
    func singleWarning() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            try "let x = 1\n".write(to: dir.appendingPathComponent("a.swift"), atomically: true, encoding: .utf8)

            let rules = RuleSet {
                Rule(id: "always-warn") { file, ctx in
                    ctx.report(on: file, message: "found code", severity: .warning)
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
                Rule(id: "always-err") { file, ctx in
                    ctx.report(on: file, message: "bad", severity: .error)
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
            let root = dir.path(percentEncoded: false)
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

            let config = Configuration(excludedPaths: ["Generated/**"], rootDirectory: root)
            let rules = RuleSet {
                Rule(id: "count") { file, ctx in
                    ctx.report(on: file, message: "found", severity: .warning)
                }
            }
            let linter = LintEngine(rules: rules, config: config)
            let result = await linter.lint(paths: [root])
            #expect(result.diagnostics.count == 1)
            #expect(result.diagnostics[0].filePath.contains("Sources"))
        }
    }

    @Test("Config rule-level include restricts to specific files")
    func ruleInclude() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let root = dir.path(percentEncoded: false)
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

            let config = Configuration(
                rootDirectory: root,
                rules: ["sources-only": RuleConfiguration(include: ["Sources/**"])],
            )
            let rules = RuleSet {
                Rule(id: "sources-only") { file, ctx in
                    ctx.report(on: file, message: "found", severity: .warning)
                }
            }
            let linter = LintEngine(rules: rules, config: config)
            let result = await linter.lint(paths: [root])
            #expect(result.diagnostics.count == 1)
        }
    }

    @Test("diagnostics sorted by file path then line")
    func sortOrder() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            try "let x = 1\nlet y = 2\n".write(to: dir.appendingPathComponent("b.swift"), atomically: true, encoding: .utf8)
            try "let z = 3\n".write(to: dir.appendingPathComponent("a.swift"), atomically: true, encoding: .utf8)

            let rules = RuleSet {
                Rule(id: "all") { file, ctx in
                    for stmt in file.statements {
                        ctx.report(on: stmt, message: "found", severity: .warning)
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
                Rule(id: "x") { _, ctx in
                    ctx.report(on: Parser.parse(source: ""), message: "never", severity: .warning)
                }
            }
            let linter = LintEngine(rules: rules)
            let result = await linter.lint(paths: [dir.path(percentEncoded: false)])
            #expect(result.diagnostics.isEmpty)
        }
    }

    @Test("config included_paths restricts file universe")
    func configIncludedPaths() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let root = dir.path(percentEncoded: false)
            let fileManager = FileManager.default
            try fileManager.createDirectory(at: dir.appendingPathComponent("Sources"), withIntermediateDirectories: true)
            try fileManager.createDirectory(at: dir.appendingPathComponent("Tests"), withIntermediateDirectories: true)
            try "let a = 1\n".write(to: dir.appendingPathComponent("Sources/a.swift"), atomically: true, encoding: .utf8)
            try "let b = 2\n".write(to: dir.appendingPathComponent("Tests/b.swift"), atomically: true, encoding: .utf8)

            let config = Configuration(includedPaths: ["Sources/**"], rootDirectory: root)
            let rules = RuleSet {
                Rule(id: "all") { file, ctx in
                    ctx.report(on: file, message: "found", severity: .warning)
                }
            }
            let linter = LintEngine(rules: rules, config: config)
            let result = await linter.lint(paths: [root])
            #expect(result.diagnostics.count == 1)
            #expect(result.diagnostics[0].filePath.contains("Sources"))
        }
    }

    @Test("config excluded_paths removes files")
    func configExcludedPaths() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let root = dir.path(percentEncoded: false)
            try "let a = 1\n".write(to: dir.appendingPathComponent("keep.swift"), atomically: true, encoding: .utf8)
            try "let b = 2\n".write(to: dir.appendingPathComponent("skip_Generated.swift"), atomically: true, encoding: .utf8)

            let config = Configuration(excludedPaths: ["**/*Generated.swift"], rootDirectory: root)
            let rules = RuleSet {
                Rule(id: "all") { file, ctx in
                    ctx.report(on: file, message: "found", severity: .warning)
                }
            }
            let linter = LintEngine(rules: rules, config: config)
            let result = await linter.lint(paths: [root])
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
                Rule(id: "r") { file, ctx in
                    ctx.report(on: file, message: "msg", severity: severity)
                }
            }
            let linter = LintEngine(rules: rules)
            let result = await linter.lint(paths: [dir.path(percentEncoded: false)])
            #expect(result.hasErrors == expectedHasErrors)
        }
    }

    @Test("three-layer intersection: yml include + RuleSet exclude + config rule include")
    func threeLayerIntersection() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let root = dir.path(percentEncoded: false)
            let fileManager = FileManager.default
            try fileManager.createDirectory(at: dir.appendingPathComponent("Sources/Core"), withIntermediateDirectories: true)
            try fileManager.createDirectory(at: dir.appendingPathComponent("Sources/Generated"), withIntermediateDirectories: true)
            try fileManager.createDirectory(at: dir.appendingPathComponent("Tests"), withIntermediateDirectories: true)

            try "let a = 1\n".write(to: dir.appendingPathComponent("Sources/Core/a.swift"), atomically: true, encoding: .utf8)
            try "let b = 2\n".write(to: dir.appendingPathComponent("Sources/Generated/b.swift"), atomically: true, encoding: .utf8)
            try "let c = 3\n".write(to: dir.appendingPathComponent("Tests/c.swift"), atomically: true, encoding: .utf8)

            let config = Configuration(
                includedPaths: ["Sources/**/*.swift"],
                excludedPaths: ["Sources/Generated/**"],
                rootDirectory: root,
                rules: ["core-only": RuleConfiguration(include: ["Sources/Core/**"])],
            )
            let rules = RuleSet {
                Rule(id: "core-only") { file, ctx in
                    ctx.report(on: file, message: "found", severity: .warning)
                }
            }

            let linter = LintEngine(rules: rules, config: config)
            let result = await linter.lint(paths: [root])
            #expect(result.diagnostics.count == 1)
            #expect(result.diagnostics[0].filePath.contains("Core/a.swift"))
        }
    }

    // MARK: - SwiftLint-compatible path resolution

    @Test("included_paths overrides CLI paths (SwiftLint behavior)")
    func configIncludedOverridesCLIPaths() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let root = dir.path(percentEncoded: false)
            let fileManager = FileManager.default
            try fileManager.createDirectory(at: dir.appendingPathComponent("Sources"), withIntermediateDirectories: true)
            try fileManager.createDirectory(at: dir.appendingPathComponent("Tests"), withIntermediateDirectories: true)

            try "let a = 1\n".write(to: dir.appendingPathComponent("Sources/a.swift"), atomically: true, encoding: .utf8)
            try "let b = 2\n".write(to: dir.appendingPathComponent("Tests/b.swift"), atomically: true, encoding: .utf8)

            let config = Configuration(includedPaths: ["Sources/**"], rootDirectory: root)
            let rules = RuleSet {
                Rule(id: "all") { file, ctx in
                    ctx.report(on: file, message: "found", severity: .warning)
                }
            }
            // Pass Tests/ as CLI path, but config includes only Sources/ — CLI path should be ignored
            let linter = LintEngine(rules: rules, config: config)
            let result = await linter.lint(paths: ["\(root)/Tests"])
            #expect(result.diagnostics.count == 1)
            #expect(result.diagnostics[0].filePath.contains("Sources/a.swift"))
        }
    }

    @Test("excluded_paths relative to config directory, not CLI path")
    func excludedRelativeToConfigDir() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let root = dir.path(percentEncoded: false)
            let fileManager = FileManager.default
            try fileManager.createDirectory(at: dir.appendingPathComponent("Sources"), withIntermediateDirectories: true)
            try fileManager.createDirectory(at: dir.appendingPathComponent("Tests"), withIntermediateDirectories: true)

            try "let a = 1\n".write(to: dir.appendingPathComponent("Sources/a.swift"), atomically: true, encoding: .utf8)
            try "let b = 2\n".write(to: dir.appendingPathComponent("Tests/b.swift"), atomically: true, encoding: .utf8)

            // excluded_paths is relative to config rootDirectory (project root), not CLI path
            let config = Configuration(excludedPaths: ["Tests/**"], rootDirectory: root)
            let rules = RuleSet {
                Rule(id: "all") { file, ctx in
                    ctx.report(on: file, message: "found", severity: .warning)
                }
            }
            let linter = LintEngine(rules: rules, config: config)
            let result = await linter.lint(paths: [root])
            #expect(result.diagnostics.count == 1)
            #expect(result.diagnostics[0].filePath.contains("Sources"))
        }
    }

    @Test("config rootDirectory resolves globs correctly even when CLI path differs")
    func configRootDirGlobResolution() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let root = dir.path(percentEncoded: false)
            let fileManager = FileManager.default
            try fileManager.createDirectory(at: dir.appendingPathComponent("Sources"), withIntermediateDirectories: true)

            try "let a = 1\n".write(to: dir.appendingPathComponent("Sources/a.swift"), atomically: true, encoding: .utf8)

            // Config says "Sources/**" relative to rootDirectory (project root)
            // Even if CLI passes ./Sources, the glob should still match
            let config = Configuration(includedPaths: ["Sources/**"], rootDirectory: root)
            let rules = RuleSet {
                Rule(id: "all") { file, ctx in
                    ctx.report(on: file, message: "found", severity: .warning)
                }
            }
            let linter = LintEngine(rules: rules, config: config)
            // This was the original bug: passing ./Sources with included_paths: Sources/** didn't match
            let result = await linter.lint(paths: ["\(root)/Sources"])
            #expect(result.diagnostics.count == 1)
        }
    }

    @Test("empty included_paths uses CLI paths (backward compat)")
    func emptyIncludedUsesCLIPaths() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let root = dir.path(percentEncoded: false)
            let fileManager = FileManager.default
            try fileManager.createDirectory(at: dir.appendingPathComponent("Sources"), withIntermediateDirectories: true)
            try fileManager.createDirectory(at: dir.appendingPathComponent("Tests"), withIntermediateDirectories: true)

            try "let a = 1\n".write(to: dir.appendingPathComponent("Sources/a.swift"), atomically: true, encoding: .utf8)
            try "let b = 2\n".write(to: dir.appendingPathComponent("Tests/b.swift"), atomically: true, encoding: .utf8)

            // No included_paths — CLI paths should be used as scan roots
            let config = Configuration(excludedPaths: [], rootDirectory: root)
            let rules = RuleSet {
                Rule(id: "all") { file, ctx in
                    ctx.report(on: file, message: "found", severity: .warning)
                }
            }
            let linter = LintEngine(rules: rules, config: config)
            let result = await linter.lint(paths: ["\(root)/Sources"])
            #expect(result.diagnostics.count == 1)
            #expect(result.diagnostics[0].filePath.contains("Sources"))
        }
    }
}

@Suite("LintEngine disabled_rules: YAML disabled_rules skips specified rules entirely")
struct LintEngineDisabledRulesTests {
    @Test("disabled_rules skips the specified rule")
    func disabledRules() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let root = dir.path(percentEncoded: false)
            try "let x = 1\n".write(to: dir.appendingPathComponent("a.swift"), atomically: true, encoding: .utf8)

            let config = Configuration(
                rootDirectory: root,
                disabledRules: ["skip-me"],
            )
            let rules = RuleSet {
                Rule(id: "skip-me") { file, ctx in
                    ctx.report(on: file, message: "should be skipped", severity: .error)
                }
                Rule(id: "keep-me") { file, ctx in
                    ctx.report(on: file, message: "should remain", severity: .warning)
                }
            }
            let linter = LintEngine(rules: rules, config: config)
            let result = await linter.lint(paths: [root])
            #expect(result.diagnostics.count == 1)
            #expect(result.diagnostics[0].ruleID == "keep-me")
        }
    }
}

// swiftlint:enable line_length force_unwrapping deep_nesting_control_flow
