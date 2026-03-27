import ArgumentParser
import Foundation
import Logging
import Synchronization

public struct LintResult: Sendable {
    public let diagnostics: [Diagnostic]
    public var hasErrors: Bool {
        diagnostics.contains { $0.severity == .error }
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
        let engine = LintEngine(rules: rules, config: loadedConfig)
        let result = await engine.lintAndOutputDiagnostics(paths: paths)

        if result.hasErrors {
            throw ExitCode(2)
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
}
