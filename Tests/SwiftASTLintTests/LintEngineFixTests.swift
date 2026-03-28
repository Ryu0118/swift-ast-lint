import FileManagerProtocol
import Foundation
@testable import SwiftASTLint
import SwiftDiagnostics
import SwiftSyntax
import Testing

@Suite("LintEngine fix mode: file write-back, remaining diagnostics, and FixResult")
struct LintEngineFixTests {
    @Test("fix mode rewrites file and removes fixable diagnostics")
    func fixRewritesFile() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let path = dir.appendingPathComponent("a.swift")
            try "var x = 1\n".write(to: path, atomically: true, encoding: .utf8)

            let rules = RuleSet { varToLetRule() }
            let engine = LintEngine(rules: rules)
            let result = await engine.fixAndOutputDiagnostics(
                paths: [dir.path(percentEncoded: false)],
            )

            let fixed = try String(contentsOf: path, encoding: .utf8)
            #expect(fixed == "let x = 1\n")
            #expect(result.fixedCount == 1)
            #expect(result.remainingDiagnostics.isEmpty)
            #expect(!result.hasErrors)
        }
    }

    @Test("fix mode leaves non-fixable diagnostics in remaining")
    func nonFixableRemains() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let path = dir.appendingPathComponent("a.swift")
            try "let x = 1\n".write(to: path, atomically: true, encoding: .utf8)

            let rules = RuleSet {
                Rule(id: "no-fix") { file, ctx in
                    ctx.report(on: file, message: "info", severity: .warning)
                }
            }
            let engine = LintEngine(rules: rules)
            let result = await engine.fixAndOutputDiagnostics(
                paths: [dir.path(percentEncoded: false)],
            )

            #expect(result.fixedCount == 0)
            #expect(result.remainingDiagnostics.count == 1)
            #expect(!result.hasErrors)
        }
    }

    @Test("fix mode with no violations does not modify file content")
    func noViolationsNoWrite() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let path = dir.appendingPathComponent("a.swift")
            let original = "let x = 1\n"
            try original.write(to: path, atomically: true, encoding: .utf8)

            let rules = RuleSet { varToLetRule() }
            let engine = LintEngine(rules: rules)
            let result = await engine.fixAndOutputDiagnostics(
                paths: [dir.path(percentEncoded: false)],
            )

            let content = try String(contentsOf: path, encoding: .utf8)
            #expect(content == original)
            #expect(result.fixedCount == 0)
        }
    }

    @Test("fix mode with mixed fixable and unfixable: fixes applied, unfixable errors remain")
    func mixedFixableUnfixable() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let path = dir.appendingPathComponent("a.swift")
            try "var x = 1\n".write(to: path, atomically: true, encoding: .utf8)

            let rules = RuleSet {
                varToLetRule()
                Rule(id: "always-error") { file, ctx in
                    ctx.report(on: file, message: "unfixable", severity: .error)
                }
            }
            let engine = LintEngine(rules: rules)
            let result = await engine.fixAndOutputDiagnostics(
                paths: [dir.path(percentEncoded: false)],
            )

            let fixed = try String(contentsOf: path, encoding: .utf8)
            #expect(fixed == "let x = 1\n")
            #expect(result.fixedCount == 1)
            #expect(result.remainingDiagnostics.count == 1)
            #expect(result.hasErrors)
        }
    }

    @Test("FixResult.hasErrors is false when only warnings remain")
    func hasErrorsWarningsOnly() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let path = dir.appendingPathComponent("a.swift")
            try "let x = 1\n".write(to: path, atomically: true, encoding: .utf8)

            let rules = RuleSet {
                Rule(id: "warn-only") { file, ctx in
                    ctx.report(on: file, message: "meh", severity: .warning)
                }
            }
            let engine = LintEngine(rules: rules)
            let result = await engine.fixAndOutputDiagnostics(
                paths: [dir.path(percentEncoded: false)],
            )

            #expect(!result.hasErrors)
        }
    }

    @Test("fix mode handles multiple files")
    func multipleFiles() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let pathA = dir.appendingPathComponent("a.swift")
            let pathB = dir.appendingPathComponent("b.swift")
            try "var a = 1\n".write(to: pathA, atomically: true, encoding: .utf8)
            try "var b = 2\n".write(to: pathB, atomically: true, encoding: .utf8)

            let rules = RuleSet { varToLetRule() }
            let engine = LintEngine(rules: rules)
            let result = await engine.fixAndOutputDiagnostics(
                paths: [dir.path(percentEncoded: false)],
            )

            let fixedA = try String(contentsOf: pathA, encoding: .utf8)
            let fixedB = try String(contentsOf: pathB, encoding: .utf8)
            #expect(fixedA == "let a = 1\n")
            #expect(fixedB == "let b = 2\n")
            #expect(result.fixedCount == 2)
        }
    }
}

// MARK: - Helpers

private func varToLetRule() -> Rule {
    Rule(id: "var-to-let") { file, ctx in
        for stmt in file.statements {
            guard let varDecl = stmt.item.as(VariableDeclSyntax.self) else { continue }
            let keyword = varDecl.bindingSpecifier
            guard keyword.tokenKind == .keyword(.var) else { continue }
            let newKeyword = keyword.with(\.tokenKind, .keyword(.let))
            ctx.reportWithFix(
                on: varDecl,
                message: "Use let",
                severity: .warning,
                fixIts: [
                    FixIt(
                        message: SimpleFixItMessage("var to let"),
                        changes: [
                            .replace(
                                oldNode: Syntax(keyword),
                                newNode: Syntax(newKeyword),
                            ),
                        ],
                    ),
                ],
            )
        }
    }
}
