@testable import Rules
import SwiftASTLint
import SwiftASTLintTestSupport
import Testing

// swiftlint:disable deep_nesting_control_flow

@Suite("deep-nesting: detects control flow nested beyond max depth via AST")
struct DeepNestingRuleTests {
    @Test("no diagnostic at depth 3 with default max 4")
    func belowThreshold() async {
        let source = """
        func foo() {
            if true {
                if true {
                    if true {
                        let _ = 0
                    }
                }
            }
        }
        """
        let diagnostics = await deepNestingRule.lint(source: source)
        #expect(diagnostics.isEmpty)
    }

    @Test("error at depth 4 with default max 4")
    func atThreshold() async {
        let source = """
        func foo() {
            if true {
                if true {
                    if true {
                        if true {
                            let _ = 0
                        }
                    }
                }
            }
        }
        """
        let diagnostics = await deepNestingRule.lint(source: source)
        #expect(diagnostics.count == 1)
        #expect(diagnostics[0].severity == .error)
        #expect(diagnostics[0].message.contains("4 levels"))
    }

    @Test("reports each deeply nested statement separately")
    func multipleViolations() async {
        let source = """
        func foo() {
            if true {
                for x in [1] {
                    while true {
                        if true {
                            let _ = 0
                        }
                        guard true else { return }
                    }
                }
            }
        }
        """
        let diagnostics = await deepNestingRule.lint(source: source)
        #expect(diagnostics.count == 2)
    }

    @Test("YAML args override max depth", arguments: [
        ("max_depth: 2\n", 1),
        ("max_depth: 10\n", 0),
    ])
    func yamlOverride(yaml: String, expectedCount: Int) async {
        let source = """
        func foo() {
            if true {
                if true {
                    let _ = 0
                }
            }
        }
        """
        let diagnostics = await deepNestingRule.lint(source: source, argsYAML: yaml)
        #expect(diagnostics.count == expectedCount)
    }

    @Test("detects all control flow types", arguments: [
        "if true { let _ = 0 }",
        "guard true else { return }",
        "for _ in [] { let _ = 0 }",
        "while true { let _ = 0 }",
        "switch 0 { default: let _ = 0 }",
        "do { let _ = 0 }",
    ])
    func allControlFlowTypes(statement: String) async {
        let source = """
        func foo() {
            if true {
                for _ in [1] {
                    while true {
                        \(statement)
                    }
                }
            }
        }
        """
        let diagnostics = await deepNestingRule.lint(source: source)
        #expect(!diagnostics.isEmpty, "Expected violation for: \(statement)")
    }

    @Test("flat control flow at same level does not accumulate depth")
    func flatSameLevel() async {
        let source = """
        func foo() {
            if true { let _ = 0 }
            if true { let _ = 0 }
            if true { let _ = 0 }
            for x in [1] { let _ = x }
        }
        """
        let diagnostics = await deepNestingRule.lint(source: source)
        #expect(diagnostics.isEmpty)
    }

    @Test("empty file produces no diagnostics")
    func emptyFile() async {
        let diagnostics = await deepNestingRule.lint(source: "")
        #expect(diagnostics.isEmpty)
    }

    @Test("depth resets between separate functions")
    func depthResetsBetweenFunctions() async {
        let source = """
        func foo() {
            if true {
                if true {
                    if true { let _ = 0 }
                }
            }
        }
        func bar() {
            if true {
                if true {
                    if true { let _ = 0 }
                }
            }
        }
        """
        let diagnostics = await deepNestingRule.lint(source: source)
        #expect(diagnostics.isEmpty)
    }
}

// swiftlint:enable deep_nesting_control_flow
