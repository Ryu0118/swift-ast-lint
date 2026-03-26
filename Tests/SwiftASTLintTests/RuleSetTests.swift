@testable import SwiftASTLint
import SwiftSyntax
import Testing

@Suite("RuleSet result builder DSL and include/exclude chaining with value semantics")
struct RuleSetTests {
    @Test("builder creates rule set with rules")
    func builder() {
        let ruleSet = RuleSet {
            Rule(id: "a", severity: .warning) { _, _ in }
            Rule(id: "b", severity: .error) { _, _ in }
        }
        #expect(ruleSet.rules.count == 2)
        #expect(ruleSet.rules[0].id == "a")
        #expect(ruleSet.rules[1].id == "b")
    }

    @Test("default global include/exclude are empty")
    func defaults() {
        let ruleSet = RuleSet {
            Rule(id: "a", severity: .warning) { _, _ in }
        }
        #expect(ruleSet.globalInclude.isEmpty)
        #expect(ruleSet.globalExclude.isEmpty)
    }

    @Test("include returns new RuleSet with patterns")
    func includeChain() {
        let ruleSet = RuleSet {
            Rule(id: "a", severity: .warning) { _, _ in }
        }.include(["Sources/**"])
        #expect(ruleSet.globalInclude == ["Sources/**"])
        #expect(ruleSet.globalExclude.isEmpty)
    }

    @Test("exclude returns new RuleSet with patterns")
    func excludeChain() {
        let ruleSet = RuleSet {
            Rule(id: "a", severity: .warning) { _, _ in }
        }.exclude(["Tests/**"])
        #expect(ruleSet.globalExclude == ["Tests/**"])
    }

    @Test("chaining include and exclude")
    func chain() {
        let ruleSet = RuleSet {
            Rule(id: "a", severity: .warning) { _, _ in }
        }
        .include(["Sources/**"])
        .exclude(["**/*Generated.swift"])
        #expect(ruleSet.globalInclude == ["Sources/**"])
        #expect(ruleSet.globalExclude == ["**/*Generated.swift"])
        #expect(ruleSet.rules.count == 1)
    }

    @Test("empty builder creates empty rule set")
    func empty() {
        let ruleSet = RuleSet {}
        #expect(ruleSet.rules.isEmpty)
    }

    @Test("buildOptional includes rules when condition is true")
    func buildOptionalTrue() {
        let includeRule = true
        let ruleSet = RuleSet {
            if includeRule {
                Rule(id: "conditional", severity: .warning) { _, _ in }
            }
        }
        #expect(ruleSet.rules.count == 1)
    }

    @Test("buildOptional excludes rules when condition is false")
    func buildOptionalFalse() {
        let includeRule = false
        let ruleSet = RuleSet {
            if includeRule {
                Rule(id: "conditional", severity: .warning) { _, _ in }
            }
        }
        #expect(ruleSet.rules.isEmpty)
    }

    @Test("buildEither selects correct branch")
    func buildEither() {
        let useFirst = true
        let ruleSet = RuleSet {
            if useFirst {
                Rule(id: "first", severity: .warning) { _, _ in }
            } else {
                Rule(id: "second", severity: .error) { _, _ in }
            }
        }
        #expect(ruleSet.rules.count == 1)
        #expect(ruleSet.rules[0].id == "first")
    }

    @Test("buildArray from for-in loop")
    func buildArray() {
        let ids = ["rule-1", "rule-2", "rule-3"]
        let ruleSet = RuleSet {
            for ruleID in ids {
                Rule(id: ruleID, severity: .warning) { _, _ in }
            }
        }
        #expect(ruleSet.rules.count == 3)
        #expect(ruleSet.rules.map(\.id) == ids)
    }
}
