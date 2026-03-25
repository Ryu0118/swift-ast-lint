import Testing
@testable import SwiftASTLint

@Suite("Severity")
struct SeverityTests {
    @Test("warning is less than error", arguments: [
        (Severity.warning, Severity.error, true),
        (Severity.error, Severity.warning, false),
        (Severity.warning, Severity.warning, false),
        (Severity.error, Severity.error, false),
    ])
    func comparison(lhs: Severity, rhs: Severity, expected: Bool) {
        #expect((lhs < rhs) == expected)
    }
}
