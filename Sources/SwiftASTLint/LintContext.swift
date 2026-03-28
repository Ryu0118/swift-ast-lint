import SwiftDiagnostics
import SwiftSyntax

/// Accumulates diagnostics reported by a single rule against a single file.
@LintActor
public final class LintContext {
    /// Absolute path of the file being linted.
    public nonisolated let filePath: String
    /// Converter for mapping AST positions to line/column locations.
    public nonisolated let sourceLocationConverter: SourceLocationConverter

    private let ruleID: String
    private var diagnostics: [Diagnostic] = []

    /// Creates a context for accumulating diagnostics from a single rule against a single file.
    public init(
        filePath: String,
        sourceLocationConverter: SourceLocationConverter,
        ruleID: String,
    ) {
        self.filePath = filePath
        self.sourceLocationConverter = sourceLocationConverter
        self.ruleID = ruleID
    }

    /// Reports a diagnostic at `node` with the given severity.
    public func report(on node: some SyntaxProtocol, message: String, severity: Severity) {
        let location = sourceLocationConverter.location(for: node.positionAfterSkippingLeadingTrivia)
        let diagnostic = Diagnostic(
            ruleID: ruleID,
            severity: severity,
            message: message,
            filePath: filePath,
            line: location.line,
            column: location.column,
        )
        diagnostics.append(diagnostic)
    }

    /// Reports a diagnostic at `node` with associated fix-its for automatic correction.
    public func reportWithFix(
        on node: some SyntaxProtocol,
        message: String,
        severity: Severity,
        fixIts: [FixIt],
    ) {
        let location = sourceLocationConverter.location(for: node.positionAfterSkippingLeadingTrivia)
        let diagnostic = Diagnostic(
            ruleID: ruleID,
            severity: severity,
            message: message,
            filePath: filePath,
            line: location.line,
            column: location.column,
            fixIts: fixIts,
        )
        diagnostics.append(diagnostic)
    }

    /// Returns all diagnostics accumulated so far.
    public func collectDiagnostics() -> [Diagnostic] {
        diagnostics
    }
}
