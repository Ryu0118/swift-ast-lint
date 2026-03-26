@testable import SwiftASTLint
import Testing

// swiftlint:disable line_length

@Suite(
    """
    Diagnostic formatted output, Comparable sorting, \
    and Equatable conformance for Xcode and AI agent compatibility
    """,
)
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
        let diagnostic = Diagnostic(
            ruleID: "r",
            severity: .warning,
            message: "型が\"大きい\"です",
            filePath: "/a.swift",
            line: 1,
            column: 1,
        )
        #expect(diagnostic.formatted.contains("型が\"大きい\"です"))
    }

    @Test("sorted by file path first, then line number")
    func sortOrder() {
        let diag1 = Diagnostic(ruleID: "r", severity: .warning, message: "m", filePath: "/b.swift", line: 10, column: 1)
        let diag2 = Diagnostic(ruleID: "r", severity: .warning, message: "m", filePath: "/a.swift", line: 20, column: 1)
        let diag3 = Diagnostic(ruleID: "r", severity: .warning, message: "m", filePath: "/a.swift", line: 5, column: 1)

        let sorted = [diag1, diag2, diag3].sorted()
        #expect(sorted[0].filePath == "/a.swift")
        #expect(sorted[0].line == 5)
        #expect(sorted[1].filePath == "/a.swift")
        #expect(sorted[1].line == 20)
        #expect(sorted[2].filePath == "/b.swift")
    }

    @Test("same file same line compares as equal")
    func sameFileAndLine() {
        let diag1 = Diagnostic(ruleID: "r1", severity: .warning, message: "m1", filePath: "/a.swift", line: 1, column: 1)
        let diag2 = Diagnostic(ruleID: "r2", severity: .error, message: "m2", filePath: "/a.swift", line: 1, column: 5)
        #expect(!(diag1 < diag2))
        #expect(!(diag2 < diag1))
    }
}

// swiftlint:enable line_length
