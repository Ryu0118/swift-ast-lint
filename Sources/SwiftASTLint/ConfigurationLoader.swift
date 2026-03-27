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
        let content = try String(contentsOfFile: path, encoding: .utf8)
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Configuration()
        }
        let decoder = YAMLDecoder()
        return try decoder.decode(Configuration.self, from: content)
    }
}
