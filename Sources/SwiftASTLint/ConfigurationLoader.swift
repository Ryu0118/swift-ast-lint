import FileManagerProtocol
import Foundation
import Yams

/// Loads a ``Configuration`` from a YAML file on disk.
public struct ConfigurationLoader {
    private let fileManager: any FileManagerProtocol

    /// Creates a loader backed by the given file manager.
    public init(fileManager: some FileManagerProtocol = FileManager.default) {
        self.fileManager = fileManager
    }

    /// Loads configuration from `path`. Returns `nil` if the file does not exist.
    public func load(from path: String) throws -> Configuration? {
        guard fileManager.fileExists(atPath: path) else {
            return nil
        }
        let configURL = URL(filePath: path).standardized
        let rootDir = configURL.deletingLastPathComponent().path(percentEncoded: false)
        let content = try String(contentsOfFile: path, encoding: .utf8)
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Configuration(rootDirectory: rootDir)
        }

        // Decode include/exclude/rules (include/exclude per rule) via Decodable
        let decoded = try YAMLDecoder().decode(DecodableConfig.self, from: content)

        // Extract args as raw YAML strings via low-level Yams API
        let rawYAML = try Yams.load(yaml: content) as? [String: Any]
        let rawRules = rawYAML?["rules"] as? [String: Any]
        let ruleConfigs = try buildRuleConfigs(decoded: decoded.rules, rawRules: rawRules)

        return Configuration(
            includedPaths: decoded.includedPaths,
            excludedPaths: decoded.excludedPaths,
            rootDirectory: rootDir,
            disabledRules: Set(decoded.disabledRules),
            rules: ruleConfigs,
            cachePath: resolveCachePath(decoded.cachePath, rootDirectory: rootDir),
        )
    }

    private func resolveCachePath(_ cachePath: String?, rootDirectory: String) -> String? {
        guard let cachePath else { return nil }
        let url = if cachePath.hasPrefix("/") {
            URL(filePath: cachePath)
        } else {
            URL(filePath: rootDirectory, directoryHint: .isDirectory).appending(path: cachePath)
        }
        return url.standardized.path(percentEncoded: false)
    }

    private func buildRuleConfigs(
        decoded: [String: RuleConfiguration],
        rawRules: [String: Any]?,
    ) throws -> [String: RuleConfiguration] {
        var result: [String: RuleConfiguration] = [:]
        for (ruleID, ruleConfig) in decoded {
            let argsYAML = try extractArgsYAML(ruleID: ruleID, rawRules: rawRules)
            result[ruleID] = RuleConfiguration(
                include: ruleConfig.include,
                exclude: ruleConfig.exclude,
                argsYAML: argsYAML,
            )
        }
        return result
    }

    private func extractArgsYAML(ruleID: String, rawRules: [String: Any]?) throws -> String? {
        guard let ruleDict = rawRules?[ruleID] as? [String: Any],
              let args = ruleDict["args"]
        else { return nil }
        return try Yams.dump(object: args)
    }
}

/// Internal Decodable wrapper for YAML parsing.
private struct DecodableConfig: Decodable {
    let includedPaths: [String]
    let excludedPaths: [String]
    let disabledRules: [String]
    let rules: [String: RuleConfiguration]
    let cachePath: String?

    private enum CodingKeys: String, CodingKey {
        case includedPaths = "included_paths"
        case excludedPaths = "excluded_paths"
        case disabledRules = "disabled_rules"
        case rules
        case cachePath = "cache_path"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        includedPaths = try container.decodeIfPresent([String].self, forKey: .includedPaths) ?? []
        excludedPaths = try container.decodeIfPresent([String].self, forKey: .excludedPaths) ?? []
        disabledRules = try container.decodeIfPresent([String].self, forKey: .disabledRules) ?? []
        rules = try container.decodeIfPresent([String: RuleConfiguration].self, forKey: .rules) ?? [:]
        cachePath = try container.decodeIfPresent(String.self, forKey: .cachePath)
    }
}
