@testable import SwiftASTLint
import SwiftSyntax
import Testing

@Suite("Rule construction: id with trailing closure check body")
struct RuleTests {
    @Test("rule stores id and accepts check closure")
    func defaults() {
        let rule = Rule(id: "test") { _, _ in }
        #expect(rule.id == "test")
    }
}
