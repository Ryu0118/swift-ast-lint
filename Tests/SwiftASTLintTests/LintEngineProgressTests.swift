import FileManagerProtocol
import Foundation
@testable import SwiftASTLint
import SwiftDiagnostics
import SwiftSyntax
import Testing

@Suite("LintEngine progress output: per-file logging and summary counts")
struct LintEngineProgressTests {
    @Test("lintAndOutputDiagnostics returns correct violation and error counts")
    func summaryCountsAreCorrect() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let path = dir.appendingPathComponent("a.swift")
            try "let x = 1\n".write(to: path, atomically: true, encoding: .utf8)

            let rules = RuleSet {
                Rule(id: "warn-rule") { file, ctx in
                    ctx.report(on: file, message: "warning", severity: .warning)
                }
                Rule(id: "error-rule") { file, ctx in
                    ctx.report(on: file, message: "error", severity: .error)
                }
            }
            let engine = LintEngine(rules: rules)
            let result = await engine.lintAndOutputDiagnostics(
                paths: [dir.path(percentEncoded: false)],
            )

            #expect(result.diagnostics.count == 2)
            #expect(result.diagnostics.count { $0.severity == .error } == 1)
            #expect(result.hasErrors)
        }
    }

    @Test("lintAndOutputDiagnostics processes all files and returns diagnostics for each")
    func allFilesAreProcessed() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let fileCount = 5
            for idx in 0 ..< fileCount {
                let path = dir.appendingPathComponent("file\(idx).swift")
                try "let x = 1\n".write(to: path, atomically: true, encoding: .utf8)
            }

            let rules = RuleSet {
                Rule(id: "always-warn") { file, ctx in
                    ctx.report(on: file, message: "warn", severity: .warning)
                }
            }
            let engine = LintEngine(rules: rules)
            let result = await engine.lintAndOutputDiagnostics(
                paths: [dir.path(percentEncoded: false)],
            )

            #expect(result.diagnostics.count == fileCount)
        }
    }

    @Test("lintAndOutputDiagnostics with no violations produces empty diagnostics")
    func noViolationsProducesEmptyResult() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let path = dir.appendingPathComponent("a.swift")
            try "let x = 1\n".write(to: path, atomically: true, encoding: .utf8)

            let rules = RuleSet {
                Rule(id: "var-only") { file, ctx in
                    reportVarDecls(in: file, context: ctx)
                }
            }
            let engine = LintEngine(rules: rules)
            let result = await engine.lintAndOutputDiagnostics(
                paths: [dir.path(percentEncoded: false)],
            )

            #expect(result.diagnostics.isEmpty)
            #expect(!result.hasErrors)
        }
    }

    @Test("fixAndOutputDiagnostics summary counts reflect remaining diagnostics only")
    func fixSummaryCountsAreCorrect() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let path = dir.appendingPathComponent("a.swift")
            try "var x = 1\n".write(to: path, atomically: true, encoding: .utf8)

            let rules = RuleSet {
                varToLetRule()
                Rule(id: "always-error") { file, ctx in
                    ctx.report(on: file, message: "unfixable error", severity: .error)
                }
            }
            let engine = LintEngine(rules: rules)
            let result = await engine.fixAndOutputDiagnostics(
                paths: [dir.path(percentEncoded: false)],
            )

            #expect(result.fixedCount == 1)
            #expect(result.remainingDiagnostics.count == 1)
            #expect(result.remainingDiagnostics[0].severity == .error)
            #expect(result.hasErrors)
        }
    }
}

// MARK: - Helpers

private func reportVarDecls(in file: SourceFileSyntax, context: LintContext) {
    for stmt in file.statements {
        guard let varDecl = stmt.item.as(VariableDeclSyntax.self),
              varDecl.bindingSpecifier.tokenKind == .keyword(.var)
        else { continue }
        context.report(on: varDecl, message: "use let", severity: .warning)
    }
}

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
