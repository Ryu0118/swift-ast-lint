@testable import SwiftASTLint
import SwiftASTLintTestSupport
import SwiftDiagnostics
import SwiftSyntax
import Testing

@Suite("lintAndFix test helper applies fix-its and returns both diagnostics and fixed source")
struct LintAndFixTests {
    @Test("fixable rule returns fixed source")
    func fixableRule() {
        let rule = Rule(id: "var-to-let") { file, ctx in
            reportVarToLet(file: file, context: ctx)
        }

        let (diagnostics, fixedSource) = rule.lintAndFix(source: "var x = 1\n")
        #expect(diagnostics.count == 1)
        #expect(diagnostics[0].isFixable)
        #expect(fixedSource == "let x = 1\n")
    }

    @Test("non-fixable rule returns nil fixedSource")
    func nonFixableRule() {
        let rule = Rule(id: "no-fix") { file, ctx in
            for stmt in file.statements {
                ctx.report(on: stmt, message: "info", severity: .warning)
            }
        }

        let (diagnostics, fixedSource) = rule.lintAndFix(source: "let x = 1\n")
        #expect(diagnostics.count == 1)
        #expect(fixedSource == nil)
    }

    @Test("mixed fixable and non-fixable reports")
    func mixedFixableAndNonFixable() {
        let rule = Rule(id: "mixed") { file, ctx in
            let stmts = Array(file.statements)
            reportVarToLet(file: file, context: ctx)
            if stmts.count > 1 {
                ctx.report(on: stmts[1], message: "Info", severity: .warning)
            }
        }

        let source = "var x = 1\nlet y = 2\n"
        let (diagnostics, fixedSource) = rule.lintAndFix(source: source)
        #expect(diagnostics.count == 2)
        #expect(diagnostics[0].isFixable)
        #expect(!diagnostics[1].isFixable)
        #expect(fixedSource == "let x = 1\nlet y = 2\n")
    }

    @Test("ParameterizedRule with fix applies correctly via lintAndFix")
    func parameterizedRuleFix() {
        let rule = ParameterizedRule(
            id: "param-var-to-let",
            defaultArguments: TargetKeywordArgs(targetKeyword: "var"),
        ) { file, ctx, args in
            reportMatchingKeyword(file: file, context: ctx, keyword: args.targetKeyword)
        }

        let (diagnostics, fixedSource) = rule.lintAndFix(source: "var x = 1\n")
        #expect(diagnostics.count == 1)
        #expect(diagnostics[0].isFixable)
        #expect(fixedSource == "let x = 1\n")
    }
}

private struct TargetKeywordArgs: Codable {
    let targetKeyword: String
}

private func reportVarToLet(file: SourceFileSyntax, context: LintContext) {
    reportMatchingKeyword(file: file, context: context, keyword: "var")
}

private func reportMatchingKeyword(
    file: SourceFileSyntax,
    context: LintContext,
    keyword targetText: String,
) {
    for stmt in file.statements {
        guard let varDecl = stmt.item.as(VariableDeclSyntax.self) else { continue }
        let keyword = varDecl.bindingSpecifier
        guard keyword.text == targetText else { continue }
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
    }
}
