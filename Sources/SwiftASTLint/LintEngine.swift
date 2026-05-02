import AsyncOperations
import Foundation
import Logging
import SwiftParser
import SwiftSyntax

package struct LintEngine {
    private static let parallelism: UInt = .init(max(1, ProcessInfo.processInfo.activeProcessorCount))

    let rules: RuleSet
    let config: Configuration?
    let fileCollector: FileCollector
    let cache: LintCache?
    let log: Logger

    package init(
        rules: RuleSet,
        config: Configuration? = nil,
        fileCollector: FileCollector = FileCollector(),
        cache: LintCache? = nil,
        logger: Logger = SwiftASTLint.logger,
    ) {
        self.rules = rules
        self.config = config
        self.fileCollector = fileCollector
        self.cache = cache
        log = logger
    }

    // MARK: - Lint

    package func lintAndOutputDiagnostics(paths: [String]) async -> LintResult {
        let batches = collectBatches(cliPaths: paths)
        let total = batches.reduce(0) { $0 + $1.files.count }
        let counter = ProgressCounter()

        var allDiagnostics: [Diagnostic] = []
        for batch in batches {
            let result = await lintFiles(
                files: batch.files,
                filterBase: batch.filterBase,
                total: total,
                counter: counter,
            )
            allDiagnostics.append(contentsOf: result.diagnostics)
        }
        cache?.save()

        let sorted = allDiagnostics.sorted()
        for diagnostic in sorted {
            log.info("\(diagnostic.formatted)")
        }

        let errorCount = sorted.count { $0.severity == .error }
        log.info("Done linting! Found \(sorted.count) violations, \(errorCount) serious in \(total) files.")
        return LintResult(diagnostics: sorted)
    }

    package func lint(paths: [String]) async -> LintResult {
        let batches = collectBatches(cliPaths: paths)
        let total = batches.reduce(0) { $0 + $1.files.count }
        let counter = ProgressCounter()

        var allDiagnostics: [Diagnostic] = []
        for batch in batches {
            let result = await lintFiles(
                files: batch.files,
                filterBase: batch.filterBase,
                total: total,
                counter: counter,
            )
            allDiagnostics.append(contentsOf: result.diagnostics)
        }
        cache?.save()
        return LintResult(diagnostics: allDiagnostics.sorted())
    }

    // MARK: - Fix

    package func fixAndOutputDiagnostics(paths: [String]) async -> FixResult {
        let batches = collectBatches(cliPaths: paths)
        let total = batches.reduce(0) { $0 + $1.files.count }
        let counter = ProgressCounter()

        var totalFixed = 0
        var allRemaining: [Diagnostic] = []

        for batch in batches {
            let (fixed, remaining) = await fixFiles(
                files: batch.files,
                filterBase: batch.filterBase,
                total: total,
                counter: counter,
            )
            totalFixed += fixed
            allRemaining.append(contentsOf: remaining)
        }

        let sorted = allRemaining.sorted()
        for diagnostic in sorted {
            log.info("\(diagnostic.formatted)")
        }

        let errorCount = sorted.count { $0.severity == .error }
        log.info("Done linting! Found \(sorted.count) violations, \(errorCount) serious in \(total) files.")
        return FixResult(fixedCount: totalFixed, remainingDiagnostics: sorted)
    }

    // MARK: - Private

    private actor ProgressCounter {
        private var value = 0
        func next() -> Int {
            value += 1
            return value
        }
    }

    private struct FileBatch {
        let files: [String]
        let filterBase: String
    }

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

    private func collectBatches(cliPaths: [String]) -> [FileBatch] {
        resolveRoots(cliPaths: cliPaths).compactMap { scanRoot, filterBase in
            let allSwiftFiles: [String]
            do {
                allSwiftFiles = try fileCollector.collectSwiftFiles(rootPath: scanRoot)
            } catch {
                log.error("Failed to collect files at \(scanRoot): \(error)")
                return nil
            }
            let files = fileCollector.applyFilters(
                files: allSwiftFiles,
                include: config?.includedPaths ?? [],
                exclude: config?.excludedPaths ?? [],
                rootPath: filterBase,
            )
            return FileBatch(files: files, filterBase: filterBase)
        }
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

    // MARK: - File processing (private)

    private func processFiles<T: Sendable>(
        files: [String],
        total: Int,
        counter: ProgressCounter,
        transform: @escaping @Sendable (String) async -> T,
    ) async -> [T] {
        await files.asyncMap(numberOfConcurrentTasks: Self.parallelism) { filePath in
            let index = await counter.next()
            let name = URL(filePath: filePath).lastPathComponent
            log.info("Linting '\(name)' (\(index)/\(total))")
            return await transform(filePath)
        }
    }

    // MARK: - Lint (private)

    private func lintFiles(
        files: [String],
        filterBase: String,
        total: Int,
        counter: ProgressCounter,
    ) async -> LintResult {
        let argsCache = buildArgsCache()
        let fileDiagnostics = await processFiles(files: files, total: total, counter: counter) { filePath in
            lintSingleFile(filePath: filePath, filterBase: filterBase, argsCache: argsCache)
        }
        return LintResult(diagnostics: Array(fileDiagnostics.joined()).sorted())
    }

    private func lintSingleFile(
        filePath: String,
        filterBase: String,
        argsCache: [String: any Sendable],
    ) -> [Diagnostic] {
        if let cachedDiagnostics = cache?.diagnostics(forFile: filePath) {
            return cachedDiagnostics
        }

        let source: String
        do {
            source = try String(contentsOfFile: filePath, encoding: .utf8)
        } catch {
            log.warning("Could not read \(filePath): \(error)")
            return []
        }
        let diagnostics = runRules(filePath: filePath, source: source, filterBase: filterBase, argsCache: argsCache)
        cache?.cache(diagnostics: diagnostics, forFile: filePath)
        return diagnostics
    }

    // MARK: - Fix (private)

    private func fixFiles(
        files: [String],
        filterBase: String,
        total: Int,
        counter: ProgressCounter,
    ) async -> (fixedCount: Int, remaining: [Diagnostic]) {
        let argsCache = buildArgsCache()
        let fileResults = await processFiles(files: files, total: total, counter: counter) { filePath in
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
            log.warning("Could not read \(filePath): \(error)")
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
            log.error("Could not write fixes to \(filePath): \(error)")
            return (0, diagnostics)
        }

        let remaining = diagnostics.filter { !$0.isFixable }
        return (appliedCount, remaining)
    }
}
