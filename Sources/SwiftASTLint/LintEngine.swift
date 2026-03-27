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
        for path in paths {
            let resolvedPath = URL(filePath: path).standardized.path(percentEncoded: false)
            let result = await lintFiles(rootPath: resolvedPath)
            allDiagnostics.append(contentsOf: result.diagnostics)
        }
        return LintResult(diagnostics: allDiagnostics.sorted())
    }

    // MARK: - Private

    @LintActor
    private func lintFiles(rootPath: String) async -> LintResult {
        let allSwiftFiles: [String]
        do {
            allSwiftFiles = try FileCollector.collectSwiftFiles(rootPath: rootPath)
        } catch {
            logger.error("Failed to collect files at \(rootPath): \(error)")
            return LintResult(diagnostics: [])
        }

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

        let fileDiagnostics = await filtered.asyncMap(
            numberOfConcurrentTasks: 10,
        ) { filePath -> [Diagnostic] in
            await lintSingleFile(filePath: filePath, rootPath: rootPath)
        }

        return LintResult(diagnostics: fileDiagnostics.flatMap(\.self).sorted())
    }

    @LintActor
    private func lintSingleFile(
        filePath: String,
        rootPath: String,
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
