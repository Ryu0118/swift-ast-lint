@testable import Rules
import SwiftASTLint
import SwiftASTLintTestSupport
import Testing

@Suite("prefer-string-raw-value-enum: detects enums with redundant description")
struct PreferStringRawValueEnumRuleTests {
    private let rule: any RuleProtocol

    init() throws {
        rule = try #require(rules.find(id: "prefer-string-raw-value-enum"))
    }

    @Test("flags enum with description returning case names as strings")
    func redundantDescription() async {
        let source = makeEnumWithDescription(
            name: "Status",
            cases: ["active", "inactive"],
            returnOwnNames: true,
        )
        let diagnostics = await rule.lint(source: source)
        #expect(diagnostics.count == 1)
        #expect(diagnostics[0].severity == .warning)
        #expect(diagnostics[0].message.contains("String raw value"))
    }

    @Test("skips enum that already has String raw type")
    func alreadyStringRawValue() async {
        let source = makeEnumWithDescription(
            name: "Status",
            cases: ["active", "inactive"],
            returnOwnNames: true,
            rawType: "String",
        )
        let diagnostics = await rule.lint(source: source)
        #expect(diagnostics.isEmpty)
    }

    @Test("skips enum without description property")
    func noDescription() async {
        let diagnostics = await rule.lint(source: "enum Direction {\ncase north\ncase south\n}")
        #expect(diagnostics.isEmpty)
    }

    @Test("skips enum where description returns different strings")
    func differentStrings() async {
        let source = makeEnumWithDescription(
            name: "Level",
            cases: ["low", "high"],
            returnOwnNames: false,
            customReturns: ["Low Priority", "High Priority"],
        )
        let diagnostics = await rule.lint(source: source)
        #expect(diagnostics.isEmpty)
    }

    @Test("skips enum with associated values")
    func associatedValues() async {
        let diagnostics = await rule.lint(source: "enum Result {\ncase success(Int)\ncase failure(String)\n}")
        #expect(diagnostics.isEmpty)
    }

    @Test("skips non-enum types")
    func nonEnumType() async {
        let diagnostics = await rule.lint(source: "struct Foo {\nvar description: String { \"foo\" }\n}")
        #expect(diagnostics.isEmpty)
    }
}

// MARK: - Test Helpers

private func makeEnumWithDescription(
    name: String,
    cases: [String],
    returnOwnNames: Bool,
    rawType: String? = nil,
    customReturns: [String]? = nil,
) -> String {
    let inheritance = rawType.map { ": \($0)" } ?? ""
    let caseLines = cases.map { "case \($0)" }.joined(separator: "\n")
    let returns = customReturns ?? (returnOwnNames ? cases : cases.map { $0.uppercased() })
    let switchCases = zip(cases, returns)
        .map { "case .\($0.0): \"\($0.1)\"" }
        .joined(separator: "\n")
    return """
    enum \(name)\(inheritance) {
    \(caseLines)
    var description: String {
    switch self {
    \(switchCases)
    }
    }
    }
    """
}
