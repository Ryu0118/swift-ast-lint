@testable import SwiftASTLint
import SwiftParser
import SwiftSyntax
import Testing

@Suite(
    """
    LintContext diagnostic collection: \
    report accumulation, severity override, and file path tracking via @LintActor
    """,
)
struct LintContextTests {
    @LintActor
    private func makeContext(source: String, filePath: String = "/test.swift") -> (SourceFileSyntax, LintContext) {
        let sourceFile = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: filePath, tree: sourceFile)
        let context = LintContext(
            filePath: filePath,
            sourceLocationConverter: converter,
            ruleID: "test-rule",
            defaultSeverity: .warning,
        )
        return (sourceFile, context)
    }

    @Test("report with default severity")
    @LintActor
    func reportDefault() throws {
        let (sourceFile, context) = makeContext(source: "let x = 1\n")
        let node = try #require(sourceFile.statements.first)
        context.report(on: node, message: "test message")
        let diagnostics = context.collectDiagnostics()
        #expect(diagnostics.count == 1)
        #expect(diagnostics[0].severity == .warning)
        #expect(diagnostics[0].message == "test message")
        #expect(diagnostics[0].ruleID == "test-rule")
        #expect(diagnostics[0].line == 1)
    }

    @Test("report with severity override")
    @LintActor
    func reportOverride() throws {
        let (sourceFile, context) = makeContext(source: "let x = 1\n")
        let node = try #require(sourceFile.statements.first)
        context.report(on: node, message: "err", severity: .error)
        let diagnostics = context.collectDiagnostics()
        #expect(diagnostics[0].severity == .error)
    }

    @Test("multiple reports accumulate")
    @LintActor
    func multipleReports() {
        let (sourceFile, context) = makeContext(source: "let x = 1\nlet y = 2\n")
        for stmt in sourceFile.statements {
            context.report(on: stmt, message: "found")
        }
        let diagnostics = context.collectDiagnostics()
        #expect(diagnostics.count == 2)
    }

    @Test("filePath is preserved")
    @LintActor
    func filePath() {
        let (_, context) = makeContext(source: "let x = 1\n", filePath: "/my/file.swift")
        #expect(context.filePath == "/my/file.swift")
    }
}
