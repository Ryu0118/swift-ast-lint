/// An ordered collection of lint rules.
public struct RuleSet: Sendable {
    /// The rules in this set.
    public let rules: [any RuleProtocol]

    /// Creates a rule set using the ``RuleSetBuilder`` result builder.
    public init(@RuleSetBuilder _ build: () -> [any RuleProtocol]) {
        rules = build()
    }
}

/// Result builder for composing an array of rules.
@resultBuilder
public struct RuleSetBuilder {
    /// Wraps a single rule into an array.
    public static func buildExpression(_ rule: some RuleProtocol) -> [any RuleProtocol] {
        [rule]
    }

    /// Concatenates rule arrays from each statement.
    public static func buildBlock(_ components: [any RuleProtocol]...) -> [any RuleProtocol] {
        components.flatMap(\.self)
    }

    /// Handles optional `if` without `else`.
    public static func buildOptional(_ component: [any RuleProtocol]?) -> [any RuleProtocol] {
        component ?? []
    }

    /// Handles the `if` branch of `if-else`.
    public static func buildEither(first component: [any RuleProtocol]) -> [any RuleProtocol] {
        component
    }

    /// Handles the `else` branch of `if-else`.
    public static func buildEither(second component: [any RuleProtocol]) -> [any RuleProtocol] {
        component
    }

    /// Handles `for-in` loops.
    public static func buildArray(_ components: [[any RuleProtocol]]) -> [any RuleProtocol] {
        components.flatMap(\.self)
    }
}
