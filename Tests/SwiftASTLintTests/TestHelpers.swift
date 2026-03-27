@testable import SwiftASTLint
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
