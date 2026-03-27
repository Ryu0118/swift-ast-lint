@testable import SwiftASTLint
import SwiftParser
import SwiftSyntax
import Testing

// swiftlint:disable line_length deep_nesting_control_flow

@Suite(
    """
    Rule examples from spec: large-public-type-per-file \
    and max-nesting-depth validated against inline Swift sources
    """,
)
struct RuleExampleTests {
    // MARK: - single-large-public-type-per-file

    private func largePubTypeRule(minBodyLines: Int = 50) -> Rule {
        Rule(id: "single-large-public-type-per-file") { file, context in
            let topLevelDecls = file.statements.compactMap { stmt -> (any DeclGroupSyntax)? in
                if let cls = stmt.item.as(ClassDeclSyntax.self) { return cls }
                if let str = stmt.item.as(StructDeclSyntax.self) { return str }
                if let enm = stmt.item.as(EnumDeclSyntax.self) { return enm }
                if let act = stmt.item.as(ActorDeclSyntax.self) { return act }
                return nil
            }
            let large = topLevelDecls.filter { decl in
                let hasAccess = decl.modifiers.contains {
                    $0.name.tokenKind == .keyword(.public) || $0.name.tokenKind == .keyword(.package)
                }
                guard hasAccess else { return false }
                let converter = context.sourceLocationConverter
                let startLine = converter.location(for: decl.memberBlock.leftBrace.positionAfterSkippingLeadingTrivia).line
                let endLine = converter.location(for: decl.memberBlock.rightBrace.positionAfterSkippingLeadingTrivia).line
                return (endLine - startLine - 1) >= minBodyLines
            }
            guard large.count > 1 else { return }
            for decl in large {
                context.report(on: decl, message: "too many large public types", severity: .error)
            }
        }
    }

    @Test("no violation with one large public type")
    @LintActor
    func singleLargeType() {
        let source = "public struct A {\n" + String(repeating: "    var x = 1\n", count: 60) + "}\n"
        let (file, ctx) = makeLintContext(source: source)
        largePubTypeRule().check(file, ctx, EmptyArguments())
        #expect(ctx.collectDiagnostics().isEmpty)
    }

    @Test("violation with two large public types")
    @LintActor
    func twoLargeTypes() {
        let typeA = "public struct A {\n" + String(repeating: "    var x = 1\n", count: 60) + "}\n"
        let typeB = "public class B {\n" + String(repeating: "    var y = 2\n", count: 60) + "}\n"
        let (file, ctx) = makeLintContext(source: typeA + typeB)
        largePubTypeRule().check(file, ctx, EmptyArguments())
        #expect(ctx.collectDiagnostics().count == 2)
    }

    @Test("two 4-line public types triggers error with minBodyLines=4")
    @LintActor
    func twoSmallPublicTypes() {
        // Each type has exactly 4 body lines (var a through var d)
        let source = """
        public struct Foo {
            var aaa = 1
            var bbb = 2
            var ccc = 3
            var ddd = 4
        }

        public struct Bar {
            var eee = 5
            var fff = 6
            var ggg = 7
            var hhh = 8
        }
        """
        let (file, ctx) = makeLintContext(source: source)
        largePubTypeRule(minBodyLines: 4).check(file, ctx, EmptyArguments())
        let diagnostics = ctx.collectDiagnostics()
        #expect(diagnostics.count == 2)
        #expect(diagnostics[0].severity == .error)
    }

    @Test("one 4-line public + one 3-line public does not trigger with minBodyLines=4")
    @LintActor
    func oneAboveOneBelow() {
        let source = """
        public struct Foo {
            var aaa = 1
            var bbb = 2
            var ccc = 3
            var ddd = 4
        }

        public struct Bar {
            var eee = 5
            var fff = 6
            var ggg = 7
        }
        """
        let (file, ctx) = makeLintContext(source: source)
        largePubTypeRule(minBodyLines: 4).check(file, ctx, EmptyArguments())
        #expect(ctx.collectDiagnostics().isEmpty)
    }

    @Test("package access level types also trigger the rule")
    @LintActor
    func packageAccessLevel() {
        let source = """
        package struct Foo {
            var aaa = 1
            var bbb = 2
            var ccc = 3
            var ddd = 4
        }

        package actor Bar {
            var eee = 5
            var fff = 6
            var ggg = 7
            var hhh = 8
        }
        """
        let (file, ctx) = makeLintContext(source: source)
        largePubTypeRule(minBodyLines: 4).check(file, ctx, EmptyArguments())
        #expect(ctx.collectDiagnostics().count == 2)
    }

    @Test("internal types are ignored even if large")
    @LintActor
    func internalTypesIgnored() {
        let source = """
        struct Foo {
            var aaa = 1
            var bbb = 2
            var ccc = 3
            var ddd = 4
        }

        struct Bar {
            var eee = 5
            var fff = 6
            var ggg = 7
            var hhh = 8
        }
        """
        let (file, ctx) = makeLintContext(source: source)
        largePubTypeRule(minBodyLines: 4).check(file, ctx, EmptyArguments())
        #expect(ctx.collectDiagnostics().isEmpty)
    }

    // MARK: - max-nesting-depth

    private func nestingRule() -> Rule {
        Rule(id: "max-nesting-depth") { file, context in
            final class NestingVisitor: SyntaxVisitor {
                var violations: [(Syntax, Int)] = []
                var depth = 0
                let maxDepth = 3
                init() {
                    super.init(viewMode: .sourceAccurate)
                }

                private func enter(_ node: some SyntaxProtocol) -> SyntaxVisitorContinueKind {
                    depth += 1
                    if depth > maxDepth { violations.append((Syntax(node), depth)) }
                    return .visitChildren
                }

                private func leave() {
                    depth -= 1
                }

                override func visit(_ node: IfExprSyntax) -> SyntaxVisitorContinueKind {
                    enter(node)
                }

                override func visitPost(_ node: IfExprSyntax) {
                    leave()
                }

                override func visit(_ node: ForStmtSyntax) -> SyntaxVisitorContinueKind {
                    enter(node)
                }

                override func visitPost(_ node: ForStmtSyntax) {
                    leave()
                }
            }
            let visitor = NestingVisitor()
            visitor.walk(file)
            for (node, depth) in visitor.violations {
                context.report(on: node, message: "nesting too deep: \(depth)", severity: .error)
            }
        }
    }

    @Test("no violation at depth 3")
    @LintActor
    func nestingOk() {
        let source = "func f() {\n    if true {\n        for _ in [1] {\n            if true { let _ = 1 }\n        }\n    }\n}"
        let (file, ctx) = makeLintContext(source: source)
        nestingRule().check(file, ctx, EmptyArguments())
        #expect(ctx.collectDiagnostics().isEmpty)
    }

    @Test("violation at depth 4")
    @LintActor
    func nestingViolation() {
        let source = "func f() {\n    if true {\n        for _ in [1] {\n            if true {\n                for _ in [1] { let _ = 1 }\n            }\n        }\n    }\n}"
        let (file, ctx) = makeLintContext(source: source)
        nestingRule().check(file, ctx, EmptyArguments())
        #expect(ctx.collectDiagnostics().count >= 1)
    }
}

// swiftlint:enable line_length deep_nesting_control_flow
