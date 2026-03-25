import SwiftSyntax

public struct Rule: Sendable {
    public let id: String
    public let severity: Severity
    public let include: [String]
    public let exclude: [String]
    public let check: @Sendable @LintActor (SourceFileSyntax, LintContext) -> Void

    public init(
        id: String,
        severity: Severity,
        include: [String] = [],
        exclude: [String] = [],
        check: @escaping @Sendable @LintActor (SourceFileSyntax, LintContext) -> Void
    ) {
        self.id = id
        self.severity = severity
        self.include = include
        self.exclude = exclude
        self.check = check
    }
}
