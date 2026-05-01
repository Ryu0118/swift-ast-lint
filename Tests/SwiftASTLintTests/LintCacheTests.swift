import FileManagerProtocol
import Foundation
@testable import SwiftASTLint
import SwiftDiagnostics
import SwiftSyntax
import Synchronization
import Testing

@Suite("LintCache: mtime reuse, invalidation, path precedence, and fix-mode bypass")
struct LintCacheTests {
    @Test("unchanged file reuses cached diagnostics and skips rule execution")
    func unchangedFileReusesCache() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let root = dir.path(percentEncoded: false)
            let source = dir.appendingPathComponent("a.swift")
            try "let x = 1\n".write(to: source, atomically: true, encoding: .utf8)

            let counter = LockedCounter()
            let rules = RuleSet { countingRule(counter: counter) }
            let cache = makeCache(directory: root, config: nil, rules: rules)

            let engine = LintEngine(rules: rules, cache: cache)
            let first = await engine.lint(paths: [root])
            let second = await engine.lint(paths: [root])

            #expect(first.diagnostics.count == 1)
            #expect(second.diagnostics == first.diagnostics)
            #expect(counter.value == 1)
        }
    }

    @Test("changed file metadata misses cache")
    func changedFileMissesCache() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let root = dir.path(percentEncoded: false)
            let source = dir.appendingPathComponent("a.swift")
            try "let x = 1\n".write(to: source, atomically: true, encoding: .utf8)

            let counter = LockedCounter()
            let rules = RuleSet { countingRule(counter: counter) }
            let cache = makeCache(directory: root, config: nil, rules: rules)
            let engine = LintEngine(rules: rules, cache: cache)

            _ = await engine.lint(paths: [root])
            try await Task.sleep(for: .seconds(1.1))
            try "let x = 1\nlet y = 2\n".write(to: source, atomically: true, encoding: .utf8)
            _ = await engine.lint(paths: [root])

            #expect(counter.value == 2)
        }
    }

    @Test("rule configuration changes cache description")
    func ruleConfigurationChangesDescription() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let root = dir.path(percentEncoded: false)
            let rules = RuleSet { Rule(id: "r") { _, _ in } }
            let firstConfig = Configuration(
                rootDirectory: root,
                rules: ["r": RuleConfiguration(argsYAML: "value: 1\n")],
            )
            let secondConfig = Configuration(
                rootDirectory: root,
                rules: ["r": RuleConfiguration(argsYAML: "value: 2\n")],
            )

            let first = LintCache.cacheDescription(configuration: firstConfig, rules: rules)
            let second = LintCache.cacheDescription(configuration: secondConfig, rules: rules)

            #expect(first != second)
        }
    }

    @Test("cached fixable diagnostics keep formatted marker")
    func cachedFixableDiagnosticsKeepMarker() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let root = dir.path(percentEncoded: false)
            let source = dir.appendingPathComponent("a.swift")
            try "var x = 1\n".write(to: source, atomically: true, encoding: .utf8)

            let rules = RuleSet { fixableRule() }
            let cache = makeCache(directory: root, config: nil, rules: rules)
            let engine = LintEngine(rules: rules, cache: cache)

            let first = await engine.lint(paths: [root])
            let second = await engine.lint(paths: [root])

            #expect(first.diagnostics[0].isFixable)
            #expect(second.diagnostics[0].formatted.hasSuffix("[fixable]"))
        }
    }

    @Test("cache can be disabled by not injecting it")
    func cacheDisabledRunsRulesAgain() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let root = dir.path(percentEncoded: false)
            let source = dir.appendingPathComponent("a.swift")
            try "let x = 1\n".write(to: source, atomically: true, encoding: .utf8)

            let counter = LockedCounter()
            let rules = RuleSet { countingRule(counter: counter) }
            let engine = LintEngine(rules: rules)

            _ = await engine.lint(paths: [root])
            _ = await engine.lint(paths: [root])

            #expect(counter.value == 2)
        }
    }

    @Test("fix mode ignores cache so fix-its are available")
    func fixModeIgnoresCache() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let root = dir.path(percentEncoded: false)
            let source = dir.appendingPathComponent("a.swift")
            try "var x = 1\n".write(to: source, atomically: true, encoding: .utf8)

            let rules = RuleSet { fixableRule() }
            let cache = makeCache(directory: root, config: nil, rules: rules)
            let lintEngine = LintEngine(rules: rules, cache: cache)
            _ = await lintEngine.lint(paths: [root])

            let fixEngine = LintEngine(rules: rules)
            let result = await fixEngine.fixAndOutputDiagnostics(paths: [root])
            let fixed = try String(contentsOf: source, encoding: .utf8)

            #expect(result.fixedCount == 1)
            #expect(fixed == "let x = 1\n")
        }
    }

    @Test("CLI cache path overrides YAML cache path and no-cache disables cache")
    func cachePathPrecedence() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let root = dir.path(percentEncoded: false)
            let executable = dir.appendingPathComponent("tool")
            try "binary".write(to: executable, atomically: true, encoding: .utf8)
            let config = Configuration(
                rootDirectory: root,
                cachePath: dir.appendingPathComponent("yaml").path(percentEncoded: false),
            )
            let rules = RuleSet { Rule(id: "r") { _, _ in } }

            let cache = try #require(Linter.makeCache(
                rules: rules,
                config: config,
                cliCachePath: dir.appendingPathComponent("cli").path(percentEncoded: false),
                noCache: false,
                fix: false,
                executablePath: executable.path(percentEncoded: false),
            ))

            #expect(cache.filePath.contains("/cli/SwiftASTLint/"))
            #expect(Linter.makeCache(
                rules: rules,
                config: config,
                cliCachePath: dir.appendingPathComponent("cli").path(percentEncoded: false),
                noCache: true,
                fix: false,
                executablePath: executable.path(percentEncoded: false),
            ) == nil)
        }
    }

    @Test("corrupt cache file is treated as a miss")
    func corruptCacheMisses() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let root = dir.path(percentEncoded: false)
            let source = dir.appendingPathComponent("a.swift")
            try "let x = 1\n".write(to: source, atomically: true, encoding: .utf8)

            let rules = RuleSet { Rule(id: "r") { _, _ in } }
            let cache = makeCache(directory: root, config: nil, rules: rules)
            try "not a plist".write(to: URL(filePath: cache.filePath), atomically: true, encoding: .utf8)

            #expect(cache.diagnostics(forFile: source.path(percentEncoded: false)) == nil)
        }
    }

    @Test("executable fingerprint changes default cache directory")
    func executableFingerprintChangesDefaultDirectory() async throws {
        try await FileManager.default.runInTemporaryDirectory { dir in
            let executable = dir.appendingPathComponent("tool")
            try "binary".write(to: executable, atomically: true, encoding: .utf8)

            let first = try #require(LintCache.ExecutableFingerprint.resolve(
                executablePath: executable.path(percentEncoded: false),
            ))
            try await Task.sleep(for: .seconds(1.1))
            try "binary v2".write(to: executable, atomically: true, encoding: .utf8)
            let second = try #require(LintCache.ExecutableFingerprint.resolve(
                executablePath: executable.path(percentEncoded: false),
            ))

            #expect(LintCache.defaultDirectory(fingerprint: first) != LintCache.defaultDirectory(fingerprint: second))
        }
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let storage = Mutex(0)

    var value: Int {
        storage.withLock { $0 }
    }

    func increment() {
        storage.withLock { $0 += 1 }
    }
}

private func makeCache(directory: String, config: Configuration?, rules: RuleSet) -> LintCache {
    LintCache(
        directory: directory,
        cacheDescription: LintCache.cacheDescription(configuration: config, rules: rules),
    )
}

private func countingRule(counter: LockedCounter) -> Rule {
    Rule(id: "counting") { file, context in
        counter.increment()
        context.report(on: file, message: "hit", severity: .warning)
    }
}

private func fixableRule() -> Rule {
    Rule(id: "var-to-let") { file, context in
        for statement in file.statements {
            guard let varDecl = statement.item.as(VariableDeclSyntax.self) else { continue }
            let keyword = varDecl.bindingSpecifier
            guard keyword.tokenKind == .keyword(.var) else { continue }
            let newKeyword = keyword.with(\.tokenKind, .keyword(.let))
            context.reportWithFix(
                on: varDecl,
                message: "Use let",
                severity: .warning,
                fixIts: [
                    FixIt(
                        message: SimpleFixItMessage("var to let"),
                        changes: [
                            .replace(
                                oldNode: Syntax(keyword),
                                newNode: Syntax(newKeyword),
                            ),
                        ],
                    ),
                ],
            )
        }
    }
}
