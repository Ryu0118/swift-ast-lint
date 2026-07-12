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

/// Root command of a generated linter executable.
///
/// Acts as a container: bare invocations (`my-linter [paths...]`) route to ``LintCommand`` via
/// `defaultSubcommand`, preserving the original single-command CLI shape, while explicit
/// subcommands (`my-linter rules`) dispatch to their own implementations.
@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
public struct Linter: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "swift-ast-lint",
        abstract: "Run SwiftAST lint rules",
        subcommands: [LintCommand.self, RulesCommand.self],
        defaultSubcommand: LintCommand.self,
    )

    /// Rules registered via ``lint(_:)``, shared with subcommands.
    static let storedRules = Mutex<RuleSet?>(nil)

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
