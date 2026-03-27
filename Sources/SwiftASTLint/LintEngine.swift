import AsyncOperations
import Foundation
import SwiftParser
import SwiftSyntax

package struct LintEngine {
    let rules: RuleSet
    let config: Configuration?

    package init(rules: RuleSet, config: Configuration? = nil) {
        self.rules = rules
        self.config = config
    }

    package func lintAndOutputDiagnostics(paths: [String]) async -> LintResult {
        let result = await lint(paths: paths)
        for diagnostic in result.diagnostics {
            logger.info("\(diagnostic.formatted)")
        }
        return result
    }

    package func lint(paths: [String]) async -> LintResult {
        var allDiagnostics: [Diagnostic] = []

        if let config, !config.includedPaths.isEmpty {
            // SwiftLint behavior: included_paths overrides CLI paths.
            // Scan from config's rootDirectory, filter relative to it.
            let result = await lintFiles(
                scanRoot: config.rootDirectory,
                filterBase: config.rootDirectory,
            )
            allDiagnostics.append(contentsOf: result.diagnostics)
        } else if let config {
            // Config exists but includedPaths empty: use CLI paths, filter relative to config dir.
            for path in paths {
                let resolved = URL(filePath: path).standardized.path(percentEncoded: false)
                let result = await lintFiles(scanRoot: resolved, filterBase: config.rootDirectory)
                allDiagnostics.append(contentsOf: result.diagnostics)
            }
        } else {
            // No config: use CLI paths, filter relative to each scan root (backward compat).
            for path in paths {
                let resolved = URL(filePath: path).standardized.path(percentEncoded: false)
                let result = await lintFiles(scanRoot: resolved, filterBase: resolved)
                allDiagnostics.append(contentsOf: result.diagnostics)
            }
        }

        return LintResult(diagnostics: allDiagnostics.sorted())
    }

    // MARK: - Private

    @LintActor
    private func lintFiles(scanRoot: String, filterBase: String) async -> LintResult {
        let allSwiftFiles: [String]
        do {
            allSwiftFiles = try FileCollector.collectSwiftFiles(rootPath: scanRoot)
        } catch {
            logger.error("Failed to collect files at \(scanRoot): \(error)")
            return LintResult(diagnostics: [])
        }

        let include = (config?.includedPaths ?? []) + rules.globalInclude
        let exclude = (config?.excludedPaths ?? []) + rules.globalExclude
        let filtered = FileCollector.applyFilters(
            files: allSwiftFiles,
            include: include,
            exclude: exclude,
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
