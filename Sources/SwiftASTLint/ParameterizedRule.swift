import SwiftSyntax

/// A lint rule with configurable arguments that can be overridden via YAML.
public struct ParameterizedRule<Arguments: Codable & Sendable>: RuleProtocol {
    /// Unique identifier for this rule.
    public let id: String
    /// Human-readable summary of what this rule detects. Surfaced by the `rules` subcommand.
    public let description: String?
    /// Default arguments used when no YAML override is provided.
    public let defaultArguments: Arguments
    private let body: @Sendable (SourceFileSyntax, LintContext, Arguments) -> Void

    /// Creates a parameterized rule.
    /// - Parameters:
    ///   - id: Unique identifier for the rule.
    ///   - description: Optional human-readable summary of what the rule detects.
    ///   - defaultArguments: Default argument values. YAML config can override these.
    ///   - check: The lint check closure receiving the source file, context, and resolved arguments.
    public init(
        id: String,
        description: String? = nil,
        defaultArguments: Arguments,
        check: @escaping @Sendable (SourceFileSyntax, LintContext, Arguments) -> Void,
    ) {
        self.id = id
        self.description = description
        self.defaultArguments = defaultArguments
        body = check
    }

    public func check(_ file: SourceFileSyntax, _ context: LintContext, _ arguments: Arguments) {
        body(file, context, arguments)
    }
}
