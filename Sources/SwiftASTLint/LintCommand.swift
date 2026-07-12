import ArgumentParser
import Foundation

/// Runs the registered lint rules over the given paths. Default subcommand of ``Linter``.
@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
public struct LintCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "lint",
        abstract: "Run SwiftAST lint rules (default)",
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

    public init() {}

    public func run() async throws {
        guard let rules = Linter.storedRules.withLock({ $0 }) else {
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
        Linter.makeCache(
            rules: rules,
            config: config,
            cliCachePath: cachePath,
            noCache: noCache,
            fix: fix,
        )
    }
}
