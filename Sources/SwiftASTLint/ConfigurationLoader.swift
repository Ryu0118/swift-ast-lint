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
    /// The returned ``Configuration/rootDirectory`` is set to the parent directory of `path`.
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
        let decoded = try YAMLDecoder().decode(Configuration.self, from: content)
        return Configuration(
            includedPaths: decoded.includedPaths,
            excludedPaths: decoded.excludedPaths,
            rootDirectory: rootDir,
        )
    }
}
