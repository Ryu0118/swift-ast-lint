import ArgumentParser
import Foundation

/// Output format for the `rules` subcommand.
enum RulesOutputFormat: String, ExpressibleByArgument {
    /// Machine-readable JSON (default) — intended for agents and tooling.
    case json
    /// Human-readable text.
    case text
}

/// Lists the rules registered in the linter together with their effective configuration.
///
/// Designed to be machine-readable first: the default output is a stable JSON document
/// (sorted keys, registration order) so that agents and tooling can discover which rules a
/// generated linter binary ships, their default and effective arguments, per-rule path scoping,
/// and whether the config disables them — without reading the linter's source.
@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
public struct RulesCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "rules",
        abstract: "List registered rules and their effective configuration",
    )

    @Option(name: .long, help: "Path to config file")
    var config: String = SwiftASTLintConstants.defaultConfigFileName

    @Option(name: .long, help: "Output format: json (default) or text")
    var format: RulesOutputFormat = .json

    public init() {}

    public func run() throws {
        guard let rules = Linter.storedRules.withLock({ $0 }) else {
            logger.error("No rules registered")
            throw ExitCode(1)
        }

        // A missing config file is a normal state (defaults-only view); a malformed one is not.
        let loadedConfig = try ConfigurationLoader().load(from: config)
        let configPath = loadedConfig == nil ? nil : config

        switch format {
        case .json:
            try emit(RulesReportBuilder.json(rules: rules, config: loadedConfig, configPath: configPath))
        case .text:
            emit(RulesReportBuilder.text(rules: rules, config: loadedConfig, configPath: configPath))
        }
    }

    // MARK: - Private

    /// Writes the report to stdout. The logger targets stderr by design; the report is the
    /// command's machine-readable output and must stay pipeable on stdout.
    private func emit(_ output: String) {
        FileHandle.standardOutput.write(Data((output + "\n").utf8))
    }
}
