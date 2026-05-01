/// Parsed representation of a `.swift-ast-lint.yml` configuration file.
public struct Configuration: Sendable, Equatable {
    /// Glob patterns for files to include in linting.
    public let includedPaths: [String]
    /// Glob patterns for files to exclude from linting.
    public let excludedPaths: [String]
    /// Absolute path to the directory containing the config file.
    public let rootDirectory: String
    /// Rule IDs to disable entirely.
    public let disabledRules: Set<String>
    /// Per-rule configuration overrides keyed by rule ID.
    public let rules: [String: RuleConfiguration]
    /// Location of the persisted lint cache.
    public let cachePath: String?

    /// Creates a configuration with the given parameters.
    public init(
        includedPaths: [String] = [],
        excludedPaths: [String] = [],
        rootDirectory: String = ".",
        disabledRules: Set<String> = [],
        rules: [String: RuleConfiguration] = [:],
        cachePath: String? = nil,
    ) {
        self.includedPaths = includedPaths
        self.excludedPaths = excludedPaths
        self.rootDirectory = rootDirectory
        self.disabledRules = disabledRules
        self.rules = rules
        self.cachePath = cachePath
    }
}

/// Per-rule configuration from YAML.
public struct RuleConfiguration: Sendable, Equatable, Decodable {
    /// Glob patterns to restrict which files this rule applies to.
    public let include: [String]
    /// Glob patterns to exclude files from this rule.
    public let exclude: [String]
    /// Raw YAML string for the args section. Decoded lazily at rule execution time.
    public let argsYAML: String?

    /// Creates a rule configuration.
    public init(include: [String] = [], exclude: [String] = [], argsYAML: String? = nil) {
        self.include = include
        self.exclude = exclude
        self.argsYAML = argsYAML
    }

    private enum CodingKeys: String, CodingKey {
        case include
        case exclude
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        include = try container.decodeIfPresent([String].self, forKey: .include) ?? []
        exclude = try container.decodeIfPresent([String].self, forKey: .exclude) ?? []
        // args is not decoded here — ConfigurationLoader extracts it as raw YAML
        argsYAML = nil
    }
}
