import FileManagerProtocol
import Foundation
@testable import SwiftASTLint
import SwiftDiagnostics
import SwiftSyntax
import Testing

@Suite("LintEngine progress output: per-file logging and summary counts")
struct LintEngineProgressTests {
    @Test("lintAndOutputDiagnostics emits Linting line for each file")
    func emitsLintingLinePerFile() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let path = dir.appendingPathComponent("a.swift")
            try "let x = 1\n".write(to: path, atomically: true, encoding: .utf8)

            let (log, handler) = makeCapturingLogger()
            let engine = LintEngine(rules: RuleSet {}, logger: log)
            _ = await engine.lintAndOutputDiagnostics(paths: [dir.path(percentEncoded: false)])

            #expect(handler.messages.contains { $0.hasPrefix("Linting 'a.swift' (") })
        }
    }

    @Test("lintAndOutputDiagnostics emits correct Done linting summary")
    func emitsDoneLintingSummary() async throws {
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
            let (log, handler) = makeCapturingLogger()
            let engine = LintEngine(rules: rules, logger: log)
            _ = await engine.lintAndOutputDiagnostics(paths: [dir.path(percentEncoded: false)])

            #expect(handler.messages.contains("Done linting! Found 2 violations, 1 serious in 1 files."))
        }
    }

    @Test("lintAndOutputDiagnostics total count is correct across multiple files")
    func totalCountIsCorrectAcrossMultipleFiles() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let fileCount = 3
            for idx in 0 ..< fileCount {
                let path = dir.appendingPathComponent("file\(idx).swift")
                try "let x = 1\n".write(to: path, atomically: true, encoding: .utf8)
            }

            let (log, handler) = makeCapturingLogger()
            let engine = LintEngine(rules: RuleSet {}, logger: log)
            _ = await engine.lintAndOutputDiagnostics(paths: [dir.path(percentEncoded: false)])

            let lintingLines = handler.messages.filter { $0.hasPrefix("Linting '") }
            #expect(lintingLines.count == fileCount)
            #expect(lintingLines.allSatisfy { $0.contains("/\(fileCount))") })
        }
    }

    @Test("lintAndOutputDiagnostics with no violations emits zero-violation summary")
    func noViolationsEmitsZeroSummary() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let path = dir.appendingPathComponent("a.swift")
            try "let x = 1\n".write(to: path, atomically: true, encoding: .utf8)

            let (log, handler) = makeCapturingLogger()
            let engine = LintEngine(rules: RuleSet { varOnlyRule() }, logger: log)
            _ = await engine.lintAndOutputDiagnostics(paths: [dir.path(percentEncoded: false)])

            #expect(handler.messages.contains("Done linting! Found 0 violations, 0 serious in 1 files."))
        }
    }

    @Test("fixAndOutputDiagnostics emits summary reflecting remaining diagnostics")
    func fixSummaryReflectsRemaining() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let path = dir.appendingPathComponent("a.swift")
            try "var x = 1\n".write(to: path, atomically: true, encoding: .utf8)

            let rules = RuleSet {
                varToLetRule()
                Rule(id: "always-error") { file, ctx in
                    ctx.report(on: file, message: "unfixable error", severity: .error)
                }
            }
            let (log, handler) = makeCapturingLogger()
            let engine = LintEngine(rules: rules, logger: log)
            _ = await engine.fixAndOutputDiagnostics(paths: [dir.path(percentEncoded: false)])

            #expect(handler.messages.contains("Done linting! Found 1 violations, 1 serious in 1 files."))
        }
    }
}

// MARK: - Helpers

private func varOnlyRule() -> Rule {
    Rule(id: "var-only") { file, ctx in
        reportVarDecls(in: file, context: ctx)
    }
}

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
