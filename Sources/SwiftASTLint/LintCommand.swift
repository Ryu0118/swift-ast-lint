import ArgumentParser
import AsyncOperations
import Foundation
import SwiftParser
import SwiftSyntax

public struct LintResult: Sendable {
    public let diagnostics: [Diagnostic]
    public var hasErrors: Bool {
        diagnostics.contains { $0.severity == .error }
    }
}

public struct LintCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "swift-ast-lint",
        abstract: "Run SwiftAST lint rules",
    )

    @Argument(help: "Paths to lint (default: current directory)")
    var paths: [String] = ["."]

    @Option(name: .long, help: "Path to config file")
    var config: String = SwiftASTLintConstants.defaultConfigFileName

    // swiftlint:disable:next identifier_name
    nonisolated(unsafe) static var _rules: RuleSet?

    public static func lint(_ rules: RuleSet) {
        _rules = rules
        main()
    }

    public init() {}

    public func run() async throws {
        guard let rules = Self._rules else {
            fputs("error: No rules registered\n", stderr)
            throw ExitCode(1)
        }

        let loadedConfig = loadConfig()
        let allDiagnostics = try await lintAllPaths(rules: rules, config: loadedConfig)
        outputDiagnostics(allDiagnostics)

        if allDiagnostics.contains(where: { $0.severity == .error }) {
            throw ExitCode(2)
        }
    }

    // MARK: - Private

    private func loadConfig() -> Configuration? {
        guard FileManager.default.fileExists(atPath: config) else {
            return nil
        }
        do {
            return try ConfigurationLoader.load(from: config)
        } catch {
            fputs("error: Failed to load \(config): \(error)\n", stderr)
            return nil
        }
    }

    private func lintAllPaths(
        rules: RuleSet,
        config: Configuration?,
    ) async throws -> [Diagnostic] {
        var allDiagnostics: [Diagnostic] = []
        for path in paths {
            let resolvedPath = URL(filePath: path).standardized.path
            let result = try await Self.lintFiles(
                rules: rules,
                config: config,
                rootPath: resolvedPath,
            )
            allDiagnostics.append(contentsOf: result.diagnostics)
        }
        return allDiagnostics.sorted()
    }

    private func outputDiagnostics(_ diagnostics: [Diagnostic]) {
        for diagnostic in diagnostics {
            Swift.print(diagnostic.formatted)
        }
    }

    // MARK: - Lint Engine

    @LintActor
    static func lintFiles(
        rules: RuleSet,
        config: Configuration?,
        rootPath: String,
    ) async throws -> LintResult {
        let allSwiftFiles = try FileCollector.collectSwiftFiles(rootPath: rootPath)

        var filtered = allSwiftFiles
        if let config {
            filtered = FileCollector.applyFilters(
                files: filtered,
                include: config.includedPaths,
                exclude: config.excludedPaths,
                rootPath: rootPath,
            )
        }
        filtered = FileCollector.applyFilters(
            files: filtered,
            include: rules.globalInclude,
            exclude: rules.globalExclude,
            rootPath: rootPath,
        )

        let fileDiagnostics = try await filtered.asyncMap(
            numberOfConcurrentTasks: 10,
        ) { filePath -> [Diagnostic] in
            await Self.lintSingleFile(filePath: filePath, rules: rules, rootPath: rootPath)
        }

        return LintResult(diagnostics: fileDiagnostics.flatMap(\.self).sorted())
    }

    @LintActor
    private static func lintSingleFile(
        filePath: String,
        rules: RuleSet,
        rootPath: String,
    ) -> [Diagnostic] {
        let source: String
        do {
            source = try String(contentsOfFile: filePath, encoding: .utf8)
        } catch {
            fputs("warning: Could not read \(filePath): \(error)\n", stderr)
            return []
        }

        let sourceFile = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: filePath, tree: sourceFile)
        let relativePath = FileCollector.makeRelative(filePath, to: rootPath)
        let applicable = rules.rules.filter { FileCollector.ruleApplies($0, to: relativePath) }

        var diagnostics: [Diagnostic] = []
        for rule in applicable {
            let context = LintContext(
                filePath: filePath,
                sourceLocationConverter: converter,
                ruleID: rule.id,
                defaultSeverity: rule.severity,
            )
            rule.check(sourceFile, context)
            diagnostics.append(contentsOf: context.collectDiagnostics())
        }
        return diagnostics
    }
}
