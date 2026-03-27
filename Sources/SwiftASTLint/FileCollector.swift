import Foundation

enum FileCollector {
    static func collectSwiftFiles(rootPath: String) throws -> [String] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: rootPath) else {
            return []
        }
        var files: [String] = []
        while let path = enumerator.nextObject() as? String {
            if path.hasSuffix(".swift") {
                files.append("\(rootPath)/\(path)")
            }
        }
        return files.sorted()
    }

    static func applyFilters(
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
                    path: makeRelative(file, to: rootPath),
                )
            }
        }
        if !exclude.isEmpty {
            filtered = filtered.filter { file in
                !GlobPattern.matchesAny(
                    patterns: exclude,
                    path: makeRelative(file, to: rootPath),
                )
            }
        }
        return filtered
    }

    static func ruleApplies(include: [String], exclude: [String], to relativePath: String) -> Bool {
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

    static func makeRelative(_ path: String, to root: String) -> String {
        if path.hasPrefix(root + "/") {
            return String(path.dropFirst(root.count + 1))
        }
        return path
    }
}
