import SwiftSyntax

/// A lint rule with no configurable arguments. Use ``ParameterizedRule`` for rules with arguments.
public struct Rule: RuleProtocol {
    /// Unique identifier for this rule.
    public let id: String
    /// Human-readable summary of what this rule detects. Surfaced by the `rules` subcommand.
    public let description: String?
    /// Empty arguments (this rule takes no configuration).
    public let defaultArguments = EmptyArguments()
    private let body: @Sendable (SourceFileSyntax, LintContext) -> Void

    /// Creates a rule with no arguments.
    /// - Parameters:
    ///   - id: Unique identifier for the rule.
    ///   - description: Optional human-readable summary of what the rule detects.
    ///   - check: The lint check closure receiving the source file and context.
    public init(
        id: String,
        description: String? = nil,
        check: @escaping @Sendable (SourceFileSyntax, LintContext) -> Void,
    ) {
        self.id = id
        self.description = description
        body = check
    }

    public func check(_ file: SourceFileSyntax, _ context: LintContext, _ arguments: EmptyArguments) {
        body(file, context)
    }
}
