@testable import SwiftASTLint
import SwiftSyntax
import Testing

@Suite("Rule construction: id, severity, include/exclude glob patterns with sensible defaults")
struct RuleTests {
    @Test("default include and exclude are empty")
    func defaults() {
        let rule = Rule(id: "test", severity: .warning) { _, _ in }
        #expect(rule.include.isEmpty)
        #expect(rule.exclude.isEmpty)
    }

    @Test("custom include and exclude")
    func customPatterns() {
        let rule = Rule(
            id: "test",
            severity: .error,
            include: ["Sources/**"],
            exclude: ["**/*Generated.swift"],
        ) { _, _ in }
        #expect(rule.include == ["Sources/**"])
        #expect(rule.exclude == ["**/*Generated.swift"])
    }
}
