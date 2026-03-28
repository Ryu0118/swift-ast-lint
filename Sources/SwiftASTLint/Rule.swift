import SwiftSyntax

/// A lint rule with no configurable arguments. Use ``ParameterizedRule`` for rules with arguments.
public struct Rule: RuleProtocol {
    /// Unique identifier for this rule.
    public let id: String
    /// Empty arguments (this rule takes no configuration).
    public let defaultArguments = EmptyArguments()
    private let body: @Sendable (SourceFileSyntax, LintContext) -> Void

    /// Creates a rule with no arguments.
    public init(
        id: String,
        check: @escaping @Sendable (SourceFileSyntax, LintContext) -> Void,
    ) {
        self.id = id
        body = check
    }

    public func check(_ file: SourceFileSyntax, _ context: LintContext, _ arguments: EmptyArguments) {
        body(file, context)
    }
}
