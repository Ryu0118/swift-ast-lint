import ArgumentParser
import FileManagerProtocol
import Foundation
import Logging
import Synchronization

public struct LintResult: Sendable {
    public let diagnostics: [Diagnostic]
    public var hasErrors: Bool {
        diagnostics.contains { $0.severity == .error }
    }
}

package struct FixResult {
    let fixedCount: Int
    let remainingDiagnostics: [Diagnostic]
    var hasErrors: Bool {
        remainingDiagnostics.contains { $0.severity == .error }
    }
}

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
public struct Linter: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "swift-ast-lint",
        abstract: "Run SwiftAST lint rules",
    )

    @Argument(help: "Paths to lint (default: current directory)")
    var paths: [String] = ["."]

    @Option(name: .long, help: "Path to config file")
    var config: String = SwiftASTLintConstants.defaultConfigFileName

    @Option(name: .long, help: "Path to cache directory")
    var cachePath: String?

    @Flag(name: .long, help: "Disable lint result cache")
    var noCache: Bool = false

    @Flag(name: .long, help: "Apply autofixes for fixable violations")
    var fix: Bool = false

    private static let storedRules = Mutex<RuleSet?>(nil)

    public static func lint(_ rules: RuleSet) async {
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardError(label: label)
            handler.logLevel = .info
            return handler
        }
        storedRules.withLock { $0 = rules }
        do {
            var command = try parseAsRoot()
            if var asyncCommand = command as? AsyncParsableCommand {
                try await asyncCommand.run()
            } else {
                try command.run()
            }
        } catch {
            exit(withError: error)
        }
    }

    public init() {}

    public func run() async throws {
        guard let rules = Self.storedRules.withLock({ $0 }) else {
            logger.error("No rules registered")
            throw ExitCode(1)
        }

        let loadedConfig = loadConfig()
        let cache = makeCache(rules: rules, config: loadedConfig)
        let engine = LintEngine(rules: rules, config: loadedConfig, cache: cache)

        if fix {
            let result = await engine.fixAndOutputDiagnostics(paths: paths)
            if result.fixedCount > 0 {
                logger.info("Fixed \(result.fixedCount) violation(s)")
            }
            if result.hasErrors {
                throw ExitCode(2)
            }
        } else {
            let result = await engine.lintAndOutputDiagnostics(paths: paths)
            if result.hasErrors {
                throw ExitCode(2)
            }
        }
    }

    // MARK: - Private

    private func loadConfig() -> Configuration? {
        do {
            return try ConfigurationLoader().load(from: config)
        } catch {
            logger.error("Failed to load \(config): \(error)")
            return nil
        }
    }

    private func makeCache(rules: RuleSet, config: Configuration?) -> LintCache? {
        Self.makeCache(
            rules: rules,
            config: config,
            cliCachePath: cachePath,
            noCache: noCache,
            fix: fix,
        )
    }

    /// Builds the lint result cache for the effective CLI/config options.
    package static func makeCache(
        rules: RuleSet,
        config: Configuration?,
        cliCachePath: String?,
        noCache: Bool,
        fix: Bool,
        executablePath: String = CommandLine.arguments[0],
        fileManager: some FileManagerProtocol = FileManager.default,
    ) -> LintCache? {
        guard !noCache, !fix else { return nil }
        guard let fingerprint = LintCache.ExecutableFingerprint.resolve(
            executablePath: executablePath,
            fileManager: fileManager,
        ) else {
            logger.warning("Could not resolve executable fingerprint. Lint cache is disabled.")
            return nil
        }

        let directory: String = if let cliCachePath {
            LintCache.customDirectory(path: cliCachePath, fingerprint: fingerprint)
        } else if let configCachePath = config?.cachePath {
            LintCache.customDirectory(path: configCachePath, fingerprint: fingerprint)
        } else {
            LintCache.defaultDirectory(fingerprint: fingerprint, fileManager: fileManager)
        }

        return LintCache(
            directory: directory,
            cacheDescription: LintCache.cacheDescription(configuration: config, rules: rules),
            fileManager: fileManager,
        )
    }
}
