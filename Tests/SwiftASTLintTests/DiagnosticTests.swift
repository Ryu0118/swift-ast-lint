import Testing
@testable import SwiftASTLint

@Suite("Diagnostic formatted output: path:line:col: severity: [id] message for Xcode and AI agent compatibility")
struct DiagnosticTests {
    @Test("formatted output", arguments: [
        (Diagnostic(ruleID: "test-rule", severity: .warning, message: "msg", filePath: "/a/b.swift", line: 42, column: 5),
         "/a/b.swift:42:5: warning: [test-rule] msg"),
        (Diagnostic(ruleID: "err-rule", severity: .error, message: "bad", filePath: "/x.swift", line: 1, column: 1),
         "/x.swift:1:1: error: [err-rule] bad"),
    ])
    func formatted(diagnostic: Diagnostic, expected: String) {
        #expect(diagnostic.formatted == expected)
    }

    @Test("special characters in message")
    func specialChars() {
        let d = Diagnostic(ruleID: "r", severity: .warning, message: "型が\"大きい\"です", filePath: "/a.swift", line: 1, column: 1)
        #expect(d.formatted.contains("型が\"大きい\"です"))
    }
}
