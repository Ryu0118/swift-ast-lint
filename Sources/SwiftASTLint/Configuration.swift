/// Parsed representation of a `.swift-ast-lint.yml` configuration file.
public struct Configuration: Sendable, Equatable, Decodable {
    /// Glob patterns for files to include in linting.
    public let includedPaths: [String]
    /// Glob patterns for files to exclude from linting.
    public let excludedPaths: [String]

    /// Creates a configuration with the given include/exclude patterns.
    public init(includedPaths: [String] = [], excludedPaths: [String] = []) {
        self.includedPaths = includedPaths
        self.excludedPaths = excludedPaths
    }

    private enum CodingKeys: String, CodingKey {
        case includedPaths = "included_paths"
        case excludedPaths = "excluded_paths"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        includedPaths = try container.decodeIfPresent([String].self, forKey: .includedPaths) ?? []
        excludedPaths = try container.decodeIfPresent([String].self, forKey: .excludedPaths) ?? []
    }
}
