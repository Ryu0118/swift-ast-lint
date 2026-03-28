@testable import SwiftASTLint
import SwiftParser
import SwiftSyntax

public extension RuleProtocol {
    /// Lints a source string and returns diagnostics. Convenience for testing rules.
    @LintActor
    func lint(source: String, fileName: String = "test.swift", argsYAML: String? = nil) -> [Diagnostic] {
        let file = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: fileName, tree: file)
        let context = LintContext(filePath: fileName, sourceLocationConverter: converter, ruleID: id)
        execute(file: file, context: context, argsYAML: argsYAML)
        return context.collectDiagnostics()
    }

    /// Lints a source string, applies any fix-its, and returns both diagnostics and the fixed source.
    @LintActor
    func lintAndFix(
        source: String,
        fileName: String = "test.swift",
        argsYAML: String? = nil,
    ) -> (diagnostics: [Diagnostic], fixedSource: String?) {
        let file = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: fileName, tree: file)
        let context = LintContext(filePath: fileName, sourceLocationConverter: converter, ruleID: id)
        execute(file: file, context: context, argsYAML: argsYAML)
        let diagnostics = context.collectDiagnostics()
        let fixIts = diagnostics.flatMap(\.fixIts)
        if fixIts.isEmpty { return (diagnostics, nil) }
        let (fixed, _) = FixApplier.applyFixes(fixIts: fixIts, to: source)
        return (diagnostics, fixed)
    }
}

public extension RuleSet {
    /// Finds a rule by ID. Returns `nil` if not found.
    func find(id: String) -> (any RuleProtocol)? {
        rules.first { $0.id == id }
    }
}
