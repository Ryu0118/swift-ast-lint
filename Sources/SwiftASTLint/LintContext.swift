import SwiftSyntax

/// Accumulates diagnostics reported by a single rule against a single file.
@LintActor
public final class LintContext {
    /// Absolute path of the file being linted.
    public nonisolated let filePath: String
    /// Converter for mapping AST positions to line/column locations.
    public nonisolated let sourceLocationConverter: SourceLocationConverter

    private let ruleID: String
    private let defaultSeverity: Severity
    private var diagnostics: [Diagnostic] = []

    init(
        filePath: String,
        sourceLocationConverter: SourceLocationConverter,
        ruleID: String,
        defaultSeverity: Severity,
    ) {
        self.filePath = filePath
        self.sourceLocationConverter = sourceLocationConverter
        self.ruleID = ruleID
        self.defaultSeverity = defaultSeverity
    }

    /// Reports a diagnostic at `node` with the rule's default severity.
    public func report(on node: some SyntaxProtocol, message: String) {
        report(on: node, message: message, severity: defaultSeverity)
    }

    /// Reports a diagnostic at `node` with an explicit severity.
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

    func collectDiagnostics() -> [Diagnostic] {
        diagnostics
    }
}
