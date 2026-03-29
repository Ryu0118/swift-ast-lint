@testable import Rules
import SwiftASTLint
import SwiftASTLintTestSupport
import Testing

@Suite("require-doc-comment: flags large functions without doc comments")
struct RequireDocCommentRuleTests {
    /// bodyLines = endLine - startLine - 1
    /// 49 statements → bodyLines = 49, below default 50
    @Test("no diagnostic for function with 49 body lines (below default 50)")
    func belowThreshold() async {
        let body = (1 ... 49).map { "    let _ = \($0)" }.joined(separator: "\n")
        let source = """
        func foo() {
        \(body)
        }
        """
        let diagnostics = await requireDocCommentRule.lint(source: source)
        #expect(diagnostics.isEmpty)
    }

    /// 50 statements → bodyLines = 50, at default threshold
    @Test("error for function with 50 body lines and no doc comment")
    func atThreshold() async {
        let body = (1 ... 50).map { "    let _ = \($0)" }.joined(separator: "\n")
        let source = """
        func foo() {
        \(body)
        }
        """
        let diagnostics = await requireDocCommentRule.lint(source: source)
        #expect(diagnostics.count == 1)
        #expect(diagnostics[0].severity == .error)
        #expect(diagnostics[0].message.contains("foo"))
    }

    @Test("no diagnostic when doc comment is present on large function")
    func withDocComment() async {
        let body = (1 ... 50).map { "    let _ = \($0)" }.joined(separator: "\n")
        let source = """
        /// Does something important.
        func foo() {
        \(body)
        }
        """
        let diagnostics = await requireDocCommentRule.lint(source: source)
        #expect(diagnostics.isEmpty)
    }

    @Test("no diagnostic when block doc comment is present on large function")
    func withBlockDocComment() async {
        let body = (1 ... 50).map { "    let _ = \($0)" }.joined(separator: "\n")
        let source = """
        /**
         Does something important.
         */
        func foo() {
        \(body)
        }
        """
        let diagnostics = await requireDocCommentRule.lint(source: source)
        #expect(diagnostics.isEmpty)
    }

    @Test("regular comment does not count as doc comment")
    func regularCommentNotDocComment() async {
        let body = (1 ... 50).map { "    let _ = \($0)" }.joined(separator: "\n")
        let source = """
        // This is just a regular comment
        func foo() {
        \(body)
        }
        """
        let diagnostics = await requireDocCommentRule.lint(source: source)
        #expect(diagnostics.count == 1)
    }

    @Test("small function is never flagged even without doc comment")
    func smallFunctionNoDocComment() async {
        let source = """
        func tiny() {
            let _ = 0
        }
        """
        let diagnostics = await requireDocCommentRule.lint(source: source)
        #expect(diagnostics.isEmpty)
    }

    @Test("function without body is not flagged")
    func protocolRequirement() async {
        let source = """
        protocol Foo {
            func bar()
        }
        """
        let diagnostics = await requireDocCommentRule.lint(source: source)
        #expect(diagnostics.isEmpty)
    }

    @Test("YAML args override min_lines", arguments: [
        ("min_lines: 10\n", 1),
        ("min_lines: 100\n", 0),
    ])
    func yamlOverride(yaml: String, expectedCount: Int) async {
        let body = (1 ... 50).map { "    let _ = \($0)" }.joined(separator: "\n")
        let source = """
        func foo() {
        \(body)
        }
        """
        let diagnostics = await requireDocCommentRule.lint(source: source, argsYAML: yaml)
        #expect(diagnostics.count == expectedCount)
    }

    @Test("detects nested method inside type without doc comment")
    func nestedMethod() async {
        let body = (1 ... 50).map { "        let _ = \($0)" }.joined(separator: "\n")
        let source = """
        struct Foo {
            func bar() {
        \(body)
            }
        }
        """
        let diagnostics = await requireDocCommentRule.lint(source: source)
        #expect(diagnostics.count == 1)
        #expect(diagnostics[0].message.contains("bar"))
    }

    @Test("empty file produces no diagnostics")
    func emptyFile() async {
        let diagnostics = await requireDocCommentRule.lint(source: "")
        #expect(diagnostics.isEmpty)
    }
}
