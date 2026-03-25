import Foundation
import Yams

public enum ConfigurationError: Error {
    case invalidFormat
}

public enum ConfigurationLoader {
    public static func load(from path: String) throws -> Configuration {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Configuration()
        }
        let parsed = try Yams.load(yaml: content)
        if parsed == nil {
            return Configuration()
        }
        guard let yaml = parsed as? [String: Any] else {
            throw ConfigurationError.invalidFormat
        }
        let included = (yaml["included_paths"] as? [String]) ?? []
        let excluded = (yaml["excluded_paths"] as? [String]) ?? []
        return Configuration(includedPaths: included, excludedPaths: excluded)
    }
}
