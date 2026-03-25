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

public struct LintCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "swift-ast-lint",
        abstract: "Run SwiftAST lint rules",
    )

    @Argument(help: "Paths to lint (default: current directory)")
    var paths: [String] = ["."]

    @Option(name: .long, help: "Path to config file")
    var config: String = ".swift-ast-lint.yml"

    // swiftlint:disable:next identifier_name
    nonisolated(unsafe) static var _rules: RuleSet?

    public static func lint(_ rules: RuleSet) {
        _rules = rules
        main()
    }

    public init() {}

    public func run() throws {
        guard let rules = Self._rules else {
            fputs("error: No rules registered\n", stderr)
            throw ExitCode(1)
        }

        let loadedConfig: Configuration?
        if FileManager.default.fileExists(atPath: config) {
            do {
                loadedConfig = try ConfigurationLoader.load(from: config)
            } catch {
                fputs("error: Failed to load \(config): \(error)\n", stderr)
                throw ExitCode(1)
            }
        } else {
            loadedConfig = nil
        }

        var allDiagnostics: [Diagnostic] = []
        for path in paths {
            let resolvedPath = (path as NSString).standardizingPath
            let result: LintResult
            do {
                result = try Self.runBlocking {
                    try await Self.lintFiles(rules: rules, config: loadedConfig, rootPath: resolvedPath)
                }
            } catch {
                fputs("error: \(error)\n", stderr)
                throw ExitCode(1)
            }
            allDiagnostics.append(contentsOf: result.diagnostics)
        }

        allDiagnostics.sort {
            if $0.filePath != $1.filePath { return $0.filePath < $1.filePath }
            return $0.line < $1.line
        }
        for diagnostic in allDiagnostics {
            Swift.print(diagnostic.formatted)
        }

        let hasErrors = allDiagnostics.contains { $0.severity == .error }
        if hasErrors { throw ExitCode(2) }
    }

    private static func runBlocking<T: Sendable>(_ body: @escaping @Sendable () async throws -> T) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var result: Result<T, any Error>?
        Task {
            do {
                result = try await .success(body())
            } catch {
                result = .failure(error)
            }
            semaphore.signal()
        }
        semaphore.wait()
        // swiftlint:disable:next force_unwrapping
        return try result!.get()
    }

    @LintActor
    static func lintFiles(
        rules: RuleSet,
        config: Configuration?,
        rootPath: String,
    ) async throws -> LintResult {
        let allSwiftFiles = try collectSwiftFiles(rootPath: rootPath)
        let ymlFiltered = filterByConfig(files: allSwiftFiles, config: config, rootPath: rootPath)
        let ruleSetFiltered = filterByPatterns(
            files: ymlFiltered,
            include: rules.globalInclude,
            exclude: rules.globalExclude,
            rootPath: rootPath,
        )

        // Process files concurrently (up to 10 at a time)
        let fileDiagnostics = try await ruleSetFiltered.asyncMap(
            numberOfConcurrentTasks: 10,
        ) { filePath -> [Diagnostic] in
            await Self.lintSingleFile(filePath: filePath, rules: rules, rootPath: rootPath)
        }

        var allDiagnostics = fileDiagnostics.flatMap(\.self)
        allDiagnostics.sort {
            if $0.filePath != $1.filePath { return $0.filePath < $1.filePath }
            return $0.line < $1.line
        }

        return LintResult(diagnostics: allDiagnostics)
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
        var diagnostics: [Diagnostic] = []

        let relativePath = makeRelative(filePath, to: rootPath)
        let applicableRules = rules.rules.filter { ruleApplies($0, to: relativePath) }

        for rule in applicableRules {
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

    // MARK: - Private

    private static func ruleApplies(_ rule: Rule, to relativePath: String) -> Bool {
        if !rule.include.isEmpty {
            guard GlobPattern.matchesAny(patterns: rule.include, path: relativePath) else {
                return false
            }
        }
        if GlobPattern.matchesAny(patterns: rule.exclude, path: relativePath) {
            return false
        }
        return true
    }

    private static func collectSwiftFiles(rootPath: String) throws -> [String] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: rootPath) else {
            return []
        }
        var files: [String] = []
        while let path = enumerator.nextObject() as? String {
            if path.hasSuffix(".swift") {
                files.append("\(rootPath)/\(path)")
            }
        }
        return files.sorted()
    }

    private static func filterByConfig(
        files: [String],
        config: Configuration?,
        rootPath: String,
    ) -> [String] {
        guard let config else { return files }

        var filtered = files
        if !config.includedPaths.isEmpty {
            filtered = filtered.filter { file in
                let rel = makeRelative(file, to: rootPath)
                return GlobPattern.matchesAny(patterns: config.includedPaths, path: rel)
            }
        }
        if !config.excludedPaths.isEmpty {
            filtered = filtered.filter { file in
                let rel = makeRelative(file, to: rootPath)
                return !GlobPattern.matchesAny(patterns: config.excludedPaths, path: rel)
            }
        }
        return filtered
    }

    private static func filterByPatterns(
        files: [String],
        include: [String],
        exclude: [String],
        rootPath: String,
    ) -> [String] {
        var filtered = files
        if !include.isEmpty {
            filtered = filtered.filter { file in
                GlobPattern.matchesAny(patterns: include, path: makeRelative(file, to: rootPath))
            }
        }
        if !exclude.isEmpty {
            filtered = filtered.filter { file in
                !GlobPattern.matchesAny(patterns: exclude, path: makeRelative(file, to: rootPath))
            }
        }
        return filtered
    }

    private static func makeRelative(_ path: String, to root: String) -> String {
        if path.hasPrefix(root + "/") {
            return String(path.dropFirst(root.count + 1))
        }
        return path
    }
}
