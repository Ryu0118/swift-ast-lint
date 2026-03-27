/// An ordered collection of lint rules with optional global include/exclude filters.
public struct RuleSet: Sendable {
    /// The rules in this set.
    public let rules: [Rule]
    /// Glob patterns that restrict which files are linted.
    public let globalInclude: [String]
    /// Glob patterns that exclude files from linting.
    public let globalExclude: [String]

    /// Creates a rule set using the ``RuleSetBuilder`` result builder.
    public init(@RuleSetBuilder _ build: () -> [Rule]) {
        rules = build()
        globalInclude = []
        globalExclude = []
    }

    private init(rules: [Rule], globalInclude: [String], globalExclude: [String]) {
        self.rules = rules
        self.globalInclude = globalInclude
        self.globalExclude = globalExclude
    }

    /// Returns a new rule set with additional include patterns.
    public func include(_ patterns: [String]) -> RuleSet {
        RuleSet(rules: rules, globalInclude: globalInclude + patterns, globalExclude: globalExclude)
    }

    /// Returns a new rule set with additional exclude patterns.
    public func exclude(_ patterns: [String]) -> RuleSet {
        RuleSet(rules: rules, globalInclude: globalInclude, globalExclude: globalExclude + patterns)
    }
}

/// Result builder for composing an array of ``Rule`` values.
@resultBuilder
public struct RuleSetBuilder {
    /// Wraps a single rule into an array.
    public static func buildExpression(_ rule: Rule) -> [Rule] {
        [rule]
    }

    /// Concatenates rule arrays from each statement.
    public static func buildBlock(_ components: [Rule]...) -> [Rule] {
        components.flatMap(\.self)
    }

    /// Handles optional `if` without `else`.
    public static func buildOptional(_ component: [Rule]?) -> [Rule] {
        component ?? []
    }

    /// Handles the `if` branch of `if-else`.
    public static func buildEither(first component: [Rule]) -> [Rule] {
        component
    }

    /// Handles the `else` branch of `if-else`.
    public static func buildEither(second component: [Rule]) -> [Rule] {
        component
    }

    /// Handles `for-in` loops.
    public static func buildArray(_ components: [[Rule]]) -> [Rule] {
        components.flatMap(\.self)
    }
}
