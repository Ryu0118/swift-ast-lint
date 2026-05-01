import AsyncOperations
import Foundation
import SwiftParser
import SwiftSyntax

package struct LintEngine {
    private static let parallelism: UInt = .init(max(1, ProcessInfo.processInfo.activeProcessorCount))

    let rules: RuleSet
    let config: Configuration?
    let fileCollector: FileCollector

    package init(rules: RuleSet, config: Configuration? = nil, fileCollector: FileCollector = FileCollector()) {
        self.rules = rules
        self.config = config
        self.fileCollector = fileCollector
    }

    // MARK: - Lint

    package func lintAndOutputDiagnostics(paths: [String]) async -> LintResult {
        let result = await lint(paths: paths)
        for diagnostic in result.diagnostics {
            logger.info("\(diagnostic.formatted)")
        }
        return result
    }

    package func lint(paths: [String]) async -> LintResult {
        let roots = resolveRoots(cliPaths: paths)
        var allDiagnostics: [Diagnostic] = []
        for (scanRoot, filterBase) in roots {
            let result = await lintFiles(scanRoot: scanRoot, filterBase: filterBase)
            allDiagnostics.append(contentsOf: result.diagnostics)
        }
        return LintResult(diagnostics: allDiagnostics.sorted())
    }

    // MARK: - Fix

    package func fixAndOutputDiagnostics(paths: [String]) async -> FixResult {
        let roots = resolveRoots(cliPaths: paths)
        var totalFixed = 0
        var allRemaining: [Diagnostic] = []

        for (scanRoot, filterBase) in roots {
            let (fixed, remaining) = await fixFiles(scanRoot: scanRoot, filterBase: filterBase)
            totalFixed += fixed
            allRemaining.append(contentsOf: remaining)
        }

        let sorted = allRemaining.sorted()
        for diagnostic in sorted {
            logger.info("\(diagnostic.formatted)")
        }

        return FixResult(fixedCount: totalFixed, remainingDiagnostics: sorted)
    }

    // MARK: - Private

    /// Resolves scan roots and filter bases from CLI paths and config.
    ///
    /// - CLI paths always determine scan roots (what directories to walk).
    /// - `filterBase` is always `config.rootDirectory` when a config exists,
    ///   so that `included_paths` / `excluded_paths` globs resolve relative to
    ///   the config file location regardless of the CLI path.
    private func resolveRoots(cliPaths: [String]) -> [(scanRoot: String, filterBase: String)] {
        let resolvedPaths = cliPaths.map { URL(filePath: $0).standardized.path(percentEncoded: false) }
        if let config {
            return resolvedPaths.map { ($0, config.rootDirectory) }
        }
        return resolvedPaths.map { ($0, $0) }
    }

    private func collectFilteredFiles(
        scanRoot: String,
        filterBase: String,
    ) throws -> [String] {
        let allSwiftFiles = try fileCollector.collectSwiftFiles(rootPath: scanRoot)
        return fileCollector.applyFilters(
            files: allSwiftFiles,
            include: config?.includedPaths ?? [],
            exclude: config?.excludedPaths ?? [],
            rootPath: filterBase,
        )
    }

    /// Builds a cache of pre-decoded rule arguments keyed by rule ID.
    ///
    /// This is computed once per lint run so that YAML decoding is not repeated for every file.
    private func buildArgsCache() -> [String: any Sendable] {
        rules.rules.reduce(into: [:]) { cache, rule in
            cache[rule.id] = rule.decodeArguments(from: config?.rules[rule.id]?.argsYAML)
        }
    }

    private func runRules(
        filePath: String,
        source: String,
        filterBase: String,
        argsCache: [String: any Sendable],
    ) -> [Diagnostic] {
        let sourceFile = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: filePath, tree: sourceFile)
        let relativePath = FileCollector.makeRelative(filePath, to: filterBase)
        let disabledRules = config?.disabledRules ?? []
        let applicable = rules.rules.filter { rule in
            guard !disabledRules.contains(rule.id) else { return false }
            let ruleConfig = config?.rules[rule.id]
            let ruleInclude = ruleConfig?.include ?? []
            let ruleExclude = ruleConfig?.exclude ?? []
            return FileCollector.ruleApplies(include: ruleInclude, exclude: ruleExclude, to: relativePath)
        }

        var diagnostics: [Diagnostic] = []
        for rule in applicable {
            let context = LintContext(
                filePath: filePath,
                sourceLocationConverter: converter,
                ruleID: rule.id,
            )
            guard let preDecodedArgs = argsCache[rule.id] else {
                preconditionFailure("Args cache missing entry for rule '\(rule.id)' — this is a programming error in LintEngine")
            }
            rule.execute(file: sourceFile, context: context, preDecodedArgs: preDecodedArgs)
            diagnostics.append(contentsOf: context.collectDiagnostics())
        }
        return diagnostics
    }

    // MARK: - Lint (private)

    private func lintFiles(scanRoot: String, filterBase: String) async -> LintResult {
        let filtered: [String]
        do {
            filtered = try collectFilteredFiles(scanRoot: scanRoot, filterBase: filterBase)
        } catch {
            logger.error("Failed to collect files at \(scanRoot): \(error)")
            return LintResult(diagnostics: [])
        }

        let argsCache = buildArgsCache()
        let fileDiagnostics = await filtered.asyncMap(
            numberOfConcurrentTasks: Self.parallelism,
        ) { filePath in
            lintSingleFile(filePath: filePath, filterBase: filterBase, argsCache: argsCache)
        }

        return LintResult(diagnostics: Array(fileDiagnostics.joined()).sorted())
    }

    private func lintSingleFile(
        filePath: String,
        filterBase: String,
        argsCache: [String: any Sendable],
    ) -> [Diagnostic] {
        let source: String
        do {
            source = try String(contentsOfFile: filePath, encoding: .utf8)
        } catch {
            logger.warning("Could not read \(filePath): \(error)")
            return []
        }
        return runRules(filePath: filePath, source: source, filterBase: filterBase, argsCache: argsCache)
    }

    // MARK: - Fix (private)

    private func fixFiles(
        scanRoot: String,
        filterBase: String,
    ) async -> (fixedCount: Int, remaining: [Diagnostic]) {
        let filtered: [String]
        do {
            filtered = try collectFilteredFiles(scanRoot: scanRoot, filterBase: filterBase)
        } catch {
            logger.error("Failed to collect files at \(scanRoot): \(error)")
            return (0, [])
        }

        let argsCache = buildArgsCache()
        let fileResults: [(fixedCount: Int, remaining: [Diagnostic])] = await filtered.asyncMap(
            numberOfConcurrentTasks: Self.parallelism,
        ) { filePath in
            fixSingleFile(filePath: filePath, filterBase: filterBase, argsCache: argsCache)
        }

        let totalFixed = fileResults.reduce(into: 0) { $0 += $1.fixedCount }
        let allRemaining = fileResults.flatMap(\.remaining)

        return (totalFixed, allRemaining)
    }

    private func fixSingleFile(
        filePath: String,
        filterBase: String,
        argsCache: [String: any Sendable],
    ) -> (fixedCount: Int, remaining: [Diagnostic]) {
        let source: String
        do {
            source = try String(contentsOfFile: filePath, encoding: .utf8)
        } catch {
            logger.warning("Could not read \(filePath): \(error)")
            return (0, [])
        }

        let diagnostics = runRules(filePath: filePath, source: source, filterBase: filterBase, argsCache: argsCache)
        let fixIts = diagnostics.flatMap(\.fixIts)

        if fixIts.isEmpty {
            return (0, diagnostics)
        }

        let (fixedSource, appliedCount) = FixApplier.applyFixes(fixIts: fixIts, to: source)

        do {
            try fixedSource.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            logger.error("Could not write fixes to \(filePath): \(error)")
            return (0, diagnostics)
        }

        let remaining = diagnostics.filter { !$0.isFixable }
        return (appliedCount, remaining)
    }
}
