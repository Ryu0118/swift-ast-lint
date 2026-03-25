import Testing
import SwiftSyntax
@testable import SwiftASTLint

@Suite("RuleSet result builder DSL and include/exclude chaining with value semantics")
struct RuleSetTests {
    @Test("builder creates rule set with rules")
    func builder() {
        let rs = RuleSet {
            Rule(id: "a", severity: .warning) { _, _ in }
            Rule(id: "b", severity: .error) { _, _ in }
        }
        #expect(rs.rules.count == 2)
        #expect(rs.rules[0].id == "a")
        #expect(rs.rules[1].id == "b")
    }

    @Test("default global include/exclude are empty")
    func defaults() {
        let rs = RuleSet {
            Rule(id: "a", severity: .warning) { _, _ in }
        }
        #expect(rs.globalInclude.isEmpty)
        #expect(rs.globalExclude.isEmpty)
    }

    @Test("include returns new RuleSet with patterns")
    func includeChain() {
        let rs = RuleSet {
            Rule(id: "a", severity: .warning) { _, _ in }
        }.include(["Sources/**"])
        #expect(rs.globalInclude == ["Sources/**"])
        #expect(rs.globalExclude.isEmpty)
    }

    @Test("exclude returns new RuleSet with patterns")
    func excludeChain() {
        let rs = RuleSet {
            Rule(id: "a", severity: .warning) { _, _ in }
        }.exclude(["Tests/**"])
        #expect(rs.globalExclude == ["Tests/**"])
    }

    @Test("chaining include and exclude")
    func chain() {
        let rs = RuleSet {
            Rule(id: "a", severity: .warning) { _, _ in }
        }
        .include(["Sources/**"])
        .exclude(["**/*Generated.swift"])
        #expect(rs.globalInclude == ["Sources/**"])
        #expect(rs.globalExclude == ["**/*Generated.swift"])
        #expect(rs.rules.count == 1)
    }

    @Test("empty builder creates empty rule set")
    func empty() {
        let rs = RuleSet { }
        #expect(rs.rules.isEmpty)
    }
}
