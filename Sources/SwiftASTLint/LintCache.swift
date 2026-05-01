import Crypto
import FileManagerProtocol
import Foundation
import Synchronization

/// Persisted lint result cache keyed by configuration fingerprint and source file metadata.
package final class LintCache: Sendable {
    private struct CacheFile: Codable {
        var entries: [String: CacheEntry]
    }

    private struct CacheEntry: Codable {
        let diagnostics: [CachedDiagnostic]
        let modificationDate: Date
        let fileSize: UInt64
    }

    private struct CachedDiagnostic: Codable {
        let ruleID: String
        let severity: Severity
        let message: String
        let filePath: String
        let line: Int
        let column: Int
        let isFixable: Bool

        init(_ diagnostic: Diagnostic) {
            ruleID = diagnostic.ruleID
            severity = diagnostic.severity
            message = diagnostic.message
            filePath = diagnostic.filePath
            line = diagnostic.line
            column = diagnostic.column
            isFixable = diagnostic.isFixable
        }

        var diagnostic: Diagnostic {
            Diagnostic(
                ruleID: ruleID,
                severity: severity,
                message: message,
                filePath: filePath,
                line: line,
                column: column,
                isFixable: isFixable,
            )
        }
    }

    private struct FileMetadata: Equatable {
        let modificationDate: Date
        let fileSize: UInt64
    }

    /// Fingerprint for the linter executable that owns a cache directory.
    package struct ExecutableFingerprint: Equatable {
        /// Stable hash value derived from executable path, modification date, and size.
        package let value: String

        /// Resolves the fingerprint for an executable on disk.
        package static func resolve(
            executablePath: String = CommandLine.arguments[0],
            fileManager: some FileManagerProtocol = FileManager.default,
        ) -> Self? {
            let path = URL(filePath: executablePath).standardized.path(percentEncoded: false)
            guard let metadata = fileMetadata(for: path, fileManager: fileManager) else {
                return nil
            }
            return Self(value: hash([
                path,
                metadata.modificationDate.timeIntervalSinceReferenceDate.description,
                metadata.fileSize.description,
            ]))
        }
    }

    private let fileURL: URL
    private let fileManager: any FileManagerProtocol
    private let state = Mutex<State>(State())

    private struct State {
        var readCache: CacheFile?
        var writeEntries: [String: CacheEntry] = [:]
    }

    /// Absolute path to the cache plist file.
    package var filePath: String {
        fileURL.path(percentEncoded: false)
    }

    /// Creates a lint cache stored under `directory` for a configuration fingerprint.
    package init(
        directory: String,
        cacheDescription: String,
        fileManager: some FileManagerProtocol = FileManager.default,
    ) {
        let directoryURL = URL(filePath: directory, directoryHint: .isDirectory)
        fileURL = directoryURL.appending(path: cacheDescription).appendingPathExtension("plist")
        self.fileManager = fileManager
    }

    /// Returns the SwiftLint-style default cache directory for the current platform.
    package static func defaultDirectory(
        fingerprint: ExecutableFingerprint,
        fileManager: some FileManagerProtocol = FileManager.default,
    ) -> String {
        let baseURL: URL
        #if os(Linux)
            baseURL = URL(filePath: "/var/tmp", directoryHint: .isDirectory)
        #else
            baseURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        #endif
        return cacheDirectory(baseURL: baseURL, fingerprint: fingerprint)
    }

    /// Returns a cache directory under a user-provided base path.
    package static func customDirectory(path: String, fingerprint: ExecutableFingerprint) -> String {
        let baseURL = URL(filePath: path, directoryHint: .isDirectory).standardized
        return cacheDirectory(baseURL: baseURL, fingerprint: fingerprint)
    }

    /// Builds the configuration fingerprint used to isolate incompatible lint results.
    package static func cacheDescription(configuration: Configuration?, rules: RuleSet) -> String {
        let payload = CacheDescriptionPayload(configuration: configuration, rules: rules)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(payload)) ?? Data()
        return hash(data)
    }

    /// Returns cached diagnostics when the file metadata still matches the stored entry.
    package func diagnostics(forFile filePath: String) -> [Diagnostic]? {
        guard let metadata = Self.fileMetadata(for: filePath, fileManager: fileManager),
              let entry = entry(forFile: filePath),
              entry.modificationDate == metadata.modificationDate,
              entry.fileSize == metadata.fileSize
        else {
            return nil
        }
        return entry.diagnostics.map(\.diagnostic)
    }

    /// Records diagnostics for a file to be persisted by ``save()``.
    package func cache(diagnostics: [Diagnostic], forFile filePath: String) {
        guard let metadata = Self.fileMetadata(for: filePath, fileManager: fileManager) else {
            return
        }
        let key = Self.standardizedPath(filePath)
        let entry = CacheEntry(
            diagnostics: diagnostics.map(CachedDiagnostic.init),
            modificationDate: metadata.modificationDate,
            fileSize: metadata.fileSize,
        )
        state.withLock {
            $0.writeEntries[key] = entry
        }
    }

    /// Writes pending cache entries to disk.
    package func save() {
        let entries = state.withLock { state -> [String: CacheEntry] in
            guard !state.writeEntries.isEmpty else { return [:] }
            let readEntries = state.readCache?.entries ?? readCache().entries
            return readEntries.merging(state.writeEntries) { _, write in write }
        }
        guard !entries.isEmpty else { return }

        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil,
            )
            let data = try PropertyListEncoder().encode(CacheFile(entries: entries))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.warning("Could not save lint cache at \(fileURL.path(percentEncoded: false)): \(error)")
        }
    }

    private static func cacheDirectory(baseURL: URL, fingerprint: ExecutableFingerprint) -> String {
        baseURL
            .appending(path: "SwiftASTLint")
            .appending(path: SwiftASTLintConstants.cacheSchemaVersion)
            .appending(path: fingerprint.value)
            .path(percentEncoded: false)
    }

    private func entry(forFile filePath: String) -> CacheEntry? {
        let key = Self.standardizedPath(filePath)
        return state.withLock { state in
            if let entry = state.writeEntries[key] {
                return entry
            }
            if let readCache = state.readCache {
                return readCache.entries[key]
            }
            let cache = readCache()
            state.readCache = cache
            return cache.entries[key]
        }
    }

    private func readCache() -> CacheFile {
        guard let data = fileManager.contents(atPath: fileURL.path(percentEncoded: false)) else {
            return CacheFile(entries: [:])
        }
        do {
            return try PropertyListDecoder().decode(CacheFile.self, from: data)
        } catch {
            logger.warning("Could not read lint cache at \(fileURL.path(percentEncoded: false)): \(error)")
            return CacheFile(entries: [:])
        }
    }

    private static func fileMetadata(for path: String, fileManager: some FileManagerProtocol) -> FileMetadata? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: standardizedPath(path)),
              let modificationDate = attributes[.modificationDate] as? Date
        else {
            return nil
        }
        let fileSize = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
        return FileMetadata(modificationDate: modificationDate, fileSize: fileSize)
    }

    private static func standardizedPath(_ path: String) -> String {
        URL(filePath: path).standardized.path(percentEncoded: false)
    }
}

private struct CacheDescriptionPayload: Encodable {
    let schemaVersion: String
    let rootDirectory: String
    let includedPaths: [String]
    let excludedPaths: [String]
    let disabledRules: [String]
    let rules: [RulePayload]

    init(configuration: Configuration?, rules: RuleSet) {
        schemaVersion = SwiftASTLintConstants.cacheSchemaVersion
        rootDirectory = configuration?.rootDirectory ?? ""
        includedPaths = configuration?.includedPaths ?? []
        excludedPaths = configuration?.excludedPaths ?? []
        disabledRules = (configuration?.disabledRules ?? []).sorted()
        self.rules = rules.rules.map { rule in
            let ruleConfiguration = configuration?.rules[rule.id]
            return RulePayload(
                id: rule.id,
                typeName: String(reflecting: type(of: rule)),
                include: ruleConfiguration?.include ?? [],
                exclude: ruleConfiguration?.exclude ?? [],
                argsYAML: ruleConfiguration?.argsYAML,
            )
        }
    }
}

private struct RulePayload: Encodable {
    let id: String
    let typeName: String
    let include: [String]
    let exclude: [String]
    let argsYAML: String?
}

private func hash(_ strings: [String]) -> String {
    let data = strings.joined(separator: "\u{0}").data(using: .utf8) ?? Data()
    return hash(data)
}

private func hash(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
