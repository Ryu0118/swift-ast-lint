import FileManagerProtocol
import Foundation
@testable import SwiftASTLint
import SwiftParser
import SwiftSyntax
import Testing

// swiftlint:disable line_length

private struct TestArgs: Codable {
    var threshold: Int = 99
}

@Suite("ParameterizedRule: YAML args override, defaults, per-rule include/exclude, ConfigurationLoader rules")
struct ParameterizedRuleTests {
    @Test("ParameterizedRule uses default arguments when no YAML args")
    func parameterizedDefaultArgs() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            try "let x = 1\n".write(to: dir.appendingPathComponent("a.swift"), atomically: true, encoding: .utf8)

            let rules = RuleSet {
                ParameterizedRule(id: "test-param", defaultArguments: TestArgs()) { file, ctx, args in
                    ctx.report(on: file, message: "threshold=\(args.threshold)", severity: .warning)
                }
            }
            let linter = LintEngine(rules: rules)
            let result = await linter.lint(paths: [dir.path(percentEncoded: false)])
            #expect(result.diagnostics.count == 1)
            #expect(result.diagnostics[0].message == "threshold=99")
        }
    }

    @Test("ParameterizedRule uses YAML args when configured")
    func parameterizedYAMLArgs() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let root = dir.path(percentEncoded: false)
            try "let x = 1\n".write(to: dir.appendingPathComponent("a.swift"), atomically: true, encoding: .utf8)

            let config = Configuration(
                rootDirectory: root,
                rules: ["test-param": RuleConfiguration(argsYAML: "threshold: 42\n")],
            )
            let rules = RuleSet {
                ParameterizedRule(id: "test-param", defaultArguments: TestArgs()) { file, ctx, args in
                    ctx.report(on: file, message: "threshold=\(args.threshold)", severity: .warning)
                }
            }
            let linter = LintEngine(rules: rules, config: config)
            let result = await linter.lint(paths: [root])
            #expect(result.diagnostics.count == 1)
            #expect(result.diagnostics[0].message == "threshold=42")
        }
    }

    @Test("ParameterizedRule falls back to defaults on invalid YAML args")
    func parameterizedInvalidArgs() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let root = dir.path(percentEncoded: false)
            try "let x = 1\n".write(to: dir.appendingPathComponent("a.swift"), atomically: true, encoding: .utf8)

            let config = Configuration(
                rootDirectory: root,
                rules: ["test-param": RuleConfiguration(argsYAML: "not_a_valid_key: abc\n")],
            )
            let rules = RuleSet {
                ParameterizedRule(id: "test-param", defaultArguments: TestArgs()) { file, ctx, args in
                    ctx.report(on: file, message: "threshold=\(args.threshold)", severity: .warning)
                }
            }
            let linter = LintEngine(rules: rules, config: config)
            let result = await linter.lint(paths: [root])
            #expect(result.diagnostics.count == 1)
            #expect(result.diagnostics[0].message == "threshold=99")
        }
    }

    @Test("per-rule include/exclude from config rules section")
    func perRuleIncludeExcludeFromConfig() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let root = dir.path(percentEncoded: false)
            let fileManager = FileManager.default
            try fileManager.createDirectory(at: dir.appendingPathComponent("Sources"), withIntermediateDirectories: true)
            try fileManager.createDirectory(at: dir.appendingPathComponent("Tests"), withIntermediateDirectories: true)

            try "let a = 1\n".write(to: dir.appendingPathComponent("Sources/a.swift"), atomically: true, encoding: .utf8)
            try "let b = 2\n".write(to: dir.appendingPathComponent("Tests/b.swift"), atomically: true, encoding: .utf8)

            let config = Configuration(
                rootDirectory: root,
                rules: [
                    "sources-only": RuleConfiguration(include: ["Sources/**"]),
                    "exclude-tests": RuleConfiguration(exclude: ["Tests/**"]),
                ],
            )
            let rules = RuleSet {
                Rule(id: "sources-only") { file, ctx in
                    ctx.report(on: file, message: "sources-only", severity: .warning)
                }
                Rule(id: "exclude-tests") { file, ctx in
                    ctx.report(on: file, message: "exclude-tests", severity: .warning)
                }
            }
            let linter = LintEngine(rules: rules, config: config)
            let result = await linter.lint(paths: [root])
            #expect(result.diagnostics.count == 2)
            #expect(result.diagnostics.allSatisfy { $0.filePath.contains("Sources") })
        }
    }

    @Test("ConfigurationLoader parses rules section with argsYAML")
    func configLoaderRulesWithArgs() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let yml = """
            included_paths:
              - "Sources/**"
            rules:
              my-rule:
                include:
                  - "Sources/Core/**"
                exclude:
                  - "**/*Generated.swift"
                args:
                  min_lines: 30
                  max_count: 5
            """
            let path = dir.appendingPathComponent(".swift-ast-lint.yml")
            try yml.write(to: path, atomically: true, encoding: .utf8)
            let config = try #require(try ConfigurationLoader().load(from: path.path(percentEncoded: false)))
            #expect(config.includedPaths == ["Sources/**"])
            #expect(config.rules.count == 1)
            let ruleConfig = try #require(config.rules["my-rule"])
            #expect(ruleConfig.include == ["Sources/Core/**"])
            #expect(ruleConfig.exclude == ["**/*Generated.swift"])
            #expect(ruleConfig.argsYAML != nil)
            #expect(ruleConfig.argsYAML!.contains("min_lines")) // swiftlint:disable:this force_unwrapping
            #expect(ruleConfig.argsYAML!.contains("30")) // swiftlint:disable:this force_unwrapping
        }
    }
}

// swiftlint:enable line_length
