@testable import SwiftASTLint
import SwiftDiagnostics
import SwiftParser
import SwiftSyntax

@LintActor
func makeLintContext(
    source: String,
    filePath: String = "test.swift",
    ruleID: String = "test",
) -> (SourceFileSyntax, LintContext) {
    let parsed = Parser.parse(source: source)
    let converter = SourceLocationConverter(fileName: filePath, tree: parsed)
    let context = LintContext(
        filePath: filePath,
        sourceLocationConverter: converter,
        ruleID: ruleID,
    )
    return (parsed, context)
}

/// Creates a minimal FixIt for tests that only need to check isFixable/Equatable.
func makeStubFixIt() -> FixIt {
    let source = "var x = 1"
    let tree = Parser.parse(source: source)
    guard let token = tree.firstToken(viewMode: .sourceAccurate) else {
        preconditionFailure("stub source must parse to at least one token")
    }
    let newToken = token.with(\.tokenKind, .keyword(.let))
    return FixIt(
        message: SimpleFixItMessage("stub"),
        changes: [.replace(oldNode: Syntax(token), newNode: Syntax(newToken))],
    )
}
