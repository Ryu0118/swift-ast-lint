import SwiftSyntax

@LintActor
public final class LintContext {
    public nonisolated let filePath: String
    public nonisolated let sourceLocationConverter: SourceLocationConverter

    private let ruleID: String
    private let defaultSeverity: Severity
    private var diagnostics: [Diagnostic] = []

    init(
        filePath: String,
        sourceLocationConverter: SourceLocationConverter,
        ruleID: String,
        defaultSeverity: Severity
    ) {
        self.filePath = filePath
        self.sourceLocationConverter = sourceLocationConverter
        self.ruleID = ruleID
        self.defaultSeverity = defaultSeverity
    }

    public func report(on node: some SyntaxProtocol, message: String) {
        report(on: node, message: message, severity: defaultSeverity)
    }

    public func report(on node: some SyntaxProtocol, message: String, severity: Severity) {
        let location = sourceLocationConverter.location(for: node.positionAfterSkippingLeadingTrivia)
        let diagnostic = Diagnostic(
            ruleID: ruleID,
            severity: severity,
            message: message,
            filePath: filePath,
            line: location.line,
            column: location.column
        )
        diagnostics.append(diagnostic)
    }

    func collectDiagnostics() -> [Diagnostic] {
        diagnostics
    }
}
