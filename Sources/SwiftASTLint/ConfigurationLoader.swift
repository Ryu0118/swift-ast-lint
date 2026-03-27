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
        guard let yaml = try Yams.load(yaml: content) as? [String: Any] else {
            return Configuration(rootDirectory: rootDir)
        }

        let includedPaths = (yaml["included_paths"] as? [String]) ?? []
        let excludedPaths = (yaml["excluded_paths"] as? [String]) ?? []
        let ruleConfigs = try parseRules(from: yaml)

        return Configuration(
            includedPaths: includedPaths,
            excludedPaths: excludedPaths,
            rootDirectory: rootDir,
            rules: ruleConfigs,
        )
    }

    private func parseRules(from yaml: [String: Any]) throws -> [String: RuleConfiguration] {
        guard let rulesDict = yaml["rules"] as? [String: Any] else { return [:] }
        var result: [String: RuleConfiguration] = [:]
        for (ruleID, value) in rulesDict {
            guard let ruleDict = value as? [String: Any] else { continue }
            result[ruleID] = try parseRuleConfig(from: ruleDict)
        }
        return result
    }

    private func parseRuleConfig(from dict: [String: Any]) throws -> RuleConfiguration {
        let include = (dict["include"] as? [String]) ?? []
        let exclude = (dict["exclude"] as? [String]) ?? []
        let argsYAML: String? = if let args = dict["args"] {
            try Yams.dump(object: args)
        } else {
            nil
        }
        return RuleConfiguration(include: include, exclude: exclude, argsYAML: argsYAML)
    }
}
