import SwiftSyntax

/// A lint rule with configurable arguments that can be overridden via YAML.
public struct ParameterizedRule<Arguments: Codable & Sendable>: RuleProtocol {
    /// Unique identifier for this rule.
    public let id: String
    /// Default arguments used when no YAML override is provided.
    public let defaultArguments: Arguments
    private let body: @Sendable @LintActor (SourceFileSyntax, LintContext, Arguments) -> Void

    /// Creates a parameterized rule.
    /// - Parameters:
    ///   - id: Unique identifier for the rule.
    ///   - defaultArguments: Default argument values. YAML config can override these.
    ///   - check: The lint check closure receiving the source file, context, and resolved arguments.
    public init(
        id: String,
        defaultArguments: Arguments,
        check: @escaping @Sendable @LintActor (SourceFileSyntax, LintContext, Arguments) -> Void,
    ) {
        self.id = id
        self.defaultArguments = defaultArguments
        body = check
    }

    @LintActor
    public func check(_ file: SourceFileSyntax, _ context: LintContext, _ arguments: Arguments) {
        body(file, context, arguments)
    }
}
