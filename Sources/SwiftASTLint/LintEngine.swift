import AsyncOperations
import Foundation
import SwiftParser
import SwiftSyntax

package struct LintEngine {
    let rules: RuleSet
    let config: Configuration?
    let fileCollector: FileCollector

    package init(rules: RuleSet, config: Configuration? = nil, fileCollector: FileCollector = FileCollector()) {
        self.rules = rules
        self.config = config
        self.fileCollector = fileCollector
    }

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

    // MARK: - Private

    /// Resolves scan roots and filter bases from CLI paths and config (SwiftLint-compatible).
    private func resolveRoots(cliPaths: [String]) -> [(scanRoot: String, filterBase: String)] {
        if let config, !config.includedPaths.isEmpty {
            return [(config.rootDirectory, config.rootDirectory)]
        }
        let resolvedPaths = cliPaths.map { URL(filePath: $0).standardized.path(percentEncoded: false) }
        if let config {
            return resolvedPaths.map { ($0, config.rootDirectory) }
        }
        return resolvedPaths.map { ($0, $0) }
    }

    @LintActor
    private func lintFiles(scanRoot: String, filterBase: String) async -> LintResult {
        let allSwiftFiles: [String]
        do {
            allSwiftFiles = try fileCollector.collectSwiftFiles(rootPath: scanRoot)
        } catch {
            logger.error("Failed to collect files at \(scanRoot): \(error)")
            return LintResult(diagnostics: [])
        }

        let filtered = fileCollector.applyFilters(
            files: allSwiftFiles,
            include: config?.includedPaths ?? [],
            exclude: config?.excludedPaths ?? [],
            rootPath: filterBase,
        )

        let fileDiagnostics = await filtered.asyncMap(
            numberOfConcurrentTasks: 10,
        ) { filePath -> [Diagnostic] in
            await lintSingleFile(filePath: filePath, filterBase: filterBase)
        }

        return LintResult(diagnostics: Array(fileDiagnostics.joined()).sorted())
    }

    @LintActor
    private func lintSingleFile(
        filePath: String,
        filterBase: String,
    ) -> [Diagnostic] {
        let source: String
        do {
            source = try String(contentsOfFile: filePath, encoding: .utf8)
        } catch {
            logger.warning("Could not read \(filePath): \(error)")
            return []
        }

        let sourceFile = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: filePath, tree: sourceFile)
        let relativePath = FileCollector.makeRelative(filePath, to: filterBase)
        let applicable = rules.rules.filter { rule in
            let ruleConfig = config?.rules[rule.id]
            let ruleInclude = ruleConfig?.include ?? []
            let ruleExclude = ruleConfig?.exclude ?? []
            return FileCollector.ruleApplies(include: ruleInclude, exclude: ruleExclude, to: relativePath)
        }

        var diagnostics: [Diagnostic] = []
        for rule in applicable {
            let configRule = config?.rules[rule.id]
            let context = LintContext(
                filePath: filePath,
                sourceLocationConverter: converter,
                ruleID: rule.id,
            )
            rule.execute(file: sourceFile, context: context, argsYAML: configRule?.argsYAML)
            diagnostics.append(contentsOf: context.collectDiagnostics())
        }
        return diagnostics
    }
}
