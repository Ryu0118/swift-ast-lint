@testable import SwiftASTLint
import SwiftParser
import SwiftSyntax
import Testing

@Suite("LintContext reportWithFix creates fixable diagnostics with associated FixIts")
struct LintContextFixTests {
    @Test("reportWithFix creates diagnostic with isFixable true")
    @LintActor
    func reportWithFixIsFixable() throws {
        let source = "var x = 1\n"
        let (sourceFile, context) = makeLintContext(source: source, ruleID: "test-rule")
        let varDecl = try #require(sourceFile.statements.first?.item.cast(VariableDeclSyntax.self))
        let keyword = varDecl.bindingSpecifier
        let newKeyword = keyword.with(\.tokenKind, .keyword(.let))

        context.reportWithFix(
            on: varDecl,
            message: "Use let",
            severity: .warning,
            fixIts: [
                FixIt(
                    message: SimpleFixItMessage("Replace var with let"),
                    changes: [.replace(oldNode: Syntax(keyword), newNode: Syntax(newKeyword))],
                ),
            ],
        )

        let diagnostics = context.collectDiagnostics()
        #expect(diagnostics.count == 1)
        #expect(diagnostics[0].isFixable)
        #expect(diagnostics[0].fixIts.count == 1)
        #expect(diagnostics[0].message == "Use let")
        #expect(diagnostics[0].ruleID == "test-rule")
    }

    @Test("report without fix creates diagnostic with isFixable false")
    @LintActor
    func reportWithoutFix() throws {
        let source = "let x = 1\n"
        let (sourceFile, context) = makeLintContext(source: source)
        let node = try #require(sourceFile.statements.first)
        context.report(on: node, message: "info", severity: .warning)

        let diagnostics = context.collectDiagnostics()
        #expect(diagnostics.count == 1)
        #expect(!diagnostics[0].isFixable)
        #expect(diagnostics[0].fixIts.isEmpty)
    }

    @Test("mixed report and reportWithFix accumulate correctly")
    @LintActor
    func mixedReports() {
        let source = "var x = 1\nlet y = 2\n"
        let (sourceFile, context) = makeLintContext(source: source, ruleID: "mixed")

        let stmts = Array(sourceFile.statements)
        let varDecl = stmts[0].item.cast(VariableDeclSyntax.self)
        let keyword = varDecl.bindingSpecifier
        let newKeyword = keyword.with(\.tokenKind, .keyword(.let))

        // First: fixable
        context.reportWithFix(
            on: varDecl,
            message: "Use let",
            severity: .warning,
            fixIts: [
                FixIt(
                    message: SimpleFixItMessage("Fix"),
                    changes: [.replace(oldNode: Syntax(keyword), newNode: Syntax(newKeyword))],
                ),
            ],
        )

        // Second: not fixable
        context.report(on: stmts[1], message: "Info only", severity: .warning)

        let diagnostics = context.collectDiagnostics()
        #expect(diagnostics.count == 2)
        #expect(diagnostics[0].isFixable)
        #expect(!diagnostics[1].isFixable)
    }

    @Test("formatted output includes [fixable] tag")
    @LintActor
    func formattedIncludesFixable() throws {
        let source = "var x = 1\n"
        let (sourceFile, context) = makeLintContext(source: source, filePath: "/a.swift", ruleID: "r")
        let varDecl = try #require(sourceFile.statements.first?.item.cast(VariableDeclSyntax.self))
        let keyword = varDecl.bindingSpecifier

        context.reportWithFix(
            on: varDecl,
            message: "msg",
            severity: .warning,
            fixIts: [
                FixIt(
                    message: SimpleFixItMessage("fix"),
                    changes: [
                        .replace(oldNode: Syntax(keyword), newNode: Syntax(keyword.with(\.tokenKind, .keyword(.let)))),
                    ],
                ),
            ],
        )

        let diagnostics = context.collectDiagnostics()
        #expect(diagnostics[0].formatted.contains("[fixable]"))
    }
}
