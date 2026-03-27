@testable import Rules
import SwiftASTLint
import Testing

// swiftlint:disable line_length

@Suite("single-large-type-per-file: detects multiple large types in one file")
struct SingleLargeTypePerFileRuleTests {
    private func makeType(name: String, lines: Int) -> String {
        let properties = (1 ... lines).map { "    var val\($0): Int = 0" }.joined(separator: "\n")
        return "struct \(name) {\n\(properties)\n}"
    }

    @Test("no diagnostic when only one large type exists")
    func singleLargeType() async {
        let diagnostics = await singleLargeTypePerFileRule.lint(source: makeType(name: "OnlyOne", lines: 60))
        #expect(diagnostics.isEmpty)
    }

    @Test("no diagnostic when two types are both small")
    func twoSmallTypes() async {
        let source = "\(makeType(name: "SmallA", lines: 5))\n\n\(makeType(name: "SmallB", lines: 5))"
        let diagnostics = await singleLargeTypePerFileRule.lint(source: source)
        #expect(diagnostics.isEmpty)
    }

    @Test("warning for two types exceeding warningLines default (50)")
    func twoLargeTypesDefaultArgs() async {
        let source = "\(makeType(name: "TypeA", lines: 55))\n\n\(makeType(name: "TypeB", lines: 55))"
        let diagnostics = await singleLargeTypePerFileRule.lint(source: source)
        #expect(diagnostics.count == 2)
        #expect(diagnostics.allSatisfy { $0.severity == .warning })
    }

    @Test("error severity when type exceeds errorLines default (100)")
    func errorSeverityForVeryLargeType() async {
        let source = "\(makeType(name: "TypeA", lines: 55))\n\n\(makeType(name: "TypeB", lines: 110))"
        let diagnostics = await singleLargeTypePerFileRule.lint(source: source)
        #expect(diagnostics.count == 2)
        let severities = diagnostics.map(\.severity)
        #expect(severities.contains(.warning))
        #expect(severities.contains(.error))
    }

    @Test("YAML args override default thresholds")
    func yamlArgsOverride() async {
        let source = "\(makeType(name: "TypeA", lines: 12))\n\n\(makeType(name: "TypeB", lines: 25))"
        let diagnostics = await singleLargeTypePerFileRule.lint(source: source, argsYAML: "warning_lines: 10\nerror_lines: 20\n")
        #expect(diagnostics.count == 2)
        let sorted = diagnostics.sorted { $0.line < $1.line }
        #expect(sorted[0].severity == .warning)
        #expect(sorted[1].severity == .error)
    }

    @Test("detects all top-level type kinds", arguments: [
        ("struct", "struct Foo {\n%@\n}\nstruct Bar {\n%@\n}"),
        ("class", "class Foo {\n%@\n}\nclass Bar {\n%@\n}"),
        ("enum", "enum Foo {\n%@\n}\nenum Bar {\n%@\n}"),
        ("actor", "actor Foo {\n%@\n}\nactor Bar {\n%@\n}"),
    ])
    func allTypeKinds(kind: String, template: String) async {
        let body = (1 ... 55).map { "    var val\($0): Int = 0" }.joined(separator: "\n")
        let source = template.replacingOccurrences(of: "%@", with: body)
        let diagnostics = await singleLargeTypePerFileRule.lint(source: source)
        #expect(diagnostics.count == 2, "Expected 2 diagnostics for \(kind) types")
    }

    @Test("ignores nested types, only top-level counts")
    func nestedTypesIgnored() async {
        let inner = (1 ... 55).map { "        var val\($0): Int = 0" }.joined(separator: "\n")
        let source = "struct Outer {\n    struct Inner {\n\(inner)\n    }\n}"
        let diagnostics = await singleLargeTypePerFileRule.lint(source: source)
        #expect(diagnostics.isEmpty)
    }

    @Test("message includes actual line count")
    func messageContainsLineCount() async {
        let source = "\(makeType(name: "TypeA", lines: 55))\n\n\(makeType(name: "TypeB", lines: 60))"
        let diagnostics = await singleLargeTypePerFileRule.lint(source: source)
        #expect(diagnostics.contains { $0.message.contains("55 lines") })
        #expect(diagnostics.contains { $0.message.contains("60 lines") })
    }
}

// swiftlint:enable line_length
