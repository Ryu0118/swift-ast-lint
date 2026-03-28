import FileManagerProtocol
import Foundation

/// Collects and filters Swift files for linting.
package struct FileCollector {
    private let fileManager: any FileManagerProtocol

    package init(fileManager: some FileManagerProtocol = FileManager.default) {
        self.fileManager = fileManager
    }

    /// Recursively collects all `.swift` files under `rootPath`, sorted alphabetically.
    package func collectSwiftFiles(rootPath: String) throws -> [String] {
        guard let enumerator = fileManager.enumerator(atPath: rootPath) else {
            return []
        }
        var files: [String] = []
        while let path = enumerator.nextObject() as? String {
            if path.hasSuffix(".swift") {
                files.append(URL(filePath: rootPath).appending(path: path).path(percentEncoded: false))
            }
        }
        return files.sorted()
    }

    /// Filters files by include/exclude glob patterns relative to `rootPath`.
    package func applyFilters(
        files: [String],
        include: [String],
        exclude: [String],
        rootPath: String,
    ) -> [String] {
        var filtered = files
        if !include.isEmpty {
            filtered = filtered.filter { file in
                GlobPattern.matchesAny(
                    patterns: include,
                    path: Self.makeRelative(file, to: rootPath),
                )
            }
        }
        if !exclude.isEmpty {
            filtered = filtered.filter { file in
                !GlobPattern.matchesAny(
                    patterns: exclude,
                    path: Self.makeRelative(file, to: rootPath),
                )
            }
        }
        return filtered
    }

    /// Checks if a rule with given include/exclude patterns applies to a file.
    package static func ruleApplies(include: [String], exclude: [String], to relativePath: String) -> Bool {
        if !include.isEmpty {
            guard GlobPattern.matchesAny(patterns: include, path: relativePath) else {
                return false
            }
        }
        if GlobPattern.matchesAny(patterns: exclude, path: relativePath) {
            return false
        }
        return true
    }

    /// Converts an absolute path to a relative path from `root`.
    package static func makeRelative(_ path: String, to root: String) -> String {
        let rootURL = URL(filePath: root, directoryHint: .isDirectory)
        let fileURL = URL(filePath: path)
        let rootPrefix = rootURL.path(percentEncoded: false)
        let filePath = fileURL.path(percentEncoded: false)
        if filePath.hasPrefix(rootPrefix) {
            return String(filePath.dropFirst(rootPrefix.count))
        }
        return path
    }
}
