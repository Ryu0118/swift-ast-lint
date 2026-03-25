public struct RuleSet: Sendable {
    public let rules: [Rule]
    public let globalInclude: [String]
    public let globalExclude: [String]

    public init(@RuleSetBuilder _ build: () -> [Rule]) {
        self.rules = build()
        self.globalInclude = []
        self.globalExclude = []
    }

    private init(rules: [Rule], globalInclude: [String], globalExclude: [String]) {
        self.rules = rules
        self.globalInclude = globalInclude
        self.globalExclude = globalExclude
    }

    public func include(_ patterns: [String]) -> RuleSet {
        RuleSet(rules: rules, globalInclude: globalInclude + patterns, globalExclude: globalExclude)
    }

    public func exclude(_ patterns: [String]) -> RuleSet {
        RuleSet(rules: rules, globalInclude: globalInclude, globalExclude: globalExclude + patterns)
    }
}

@resultBuilder
public struct RuleSetBuilder {
    public static func buildBlock(_ rules: Rule...) -> [Rule] {
        Array(rules)
    }

    public static func buildOptional(_ component: [Rule]?) -> [Rule] {
        component ?? []
    }

    public static func buildEither(first component: [Rule]) -> [Rule] {
        component
    }

    public static func buildEither(second component: [Rule]) -> [Rule] {
        component
    }

    public static func buildArray(_ components: [[Rule]]) -> [Rule] {
        components.flatMap { $0 }
    }
}
