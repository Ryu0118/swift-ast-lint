import SwiftParser
import SwiftSyntax
import Yams

/// A type-erased empty arguments type for rules that need no configuration.
public struct EmptyArguments: Codable, Sendable {
    /// Creates empty arguments.
    public init() {}
}

/// A lint rule that checks a source file and reports diagnostics.
public protocol RuleProtocol: Sendable {
    /// The arguments type for this rule. Defaults to ``EmptyArguments``.
    associatedtype Arguments: Codable & Sendable = EmptyArguments

    /// Unique identifier for this rule.
    var id: String { get }

    /// Default arguments used when no YAML override is provided.
    var defaultArguments: Arguments { get }

    /// Checks a source file and reports diagnostics via the context.
    @LintActor func check(_ file: SourceFileSyntax, _ context: LintContext, _ arguments: Arguments)
}

public extension RuleProtocol {
    /// Lints a source string and returns diagnostics. Convenience for testing rules.
    @LintActor
    func lint(source: String, fileName: String = "test.swift", argsYAML: String? = nil) -> [Diagnostic] {
        let file = SwiftParser.Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: fileName, tree: file)
        let context = LintContext(filePath: fileName, sourceLocationConverter: converter, ruleID: id)
        execute(file: file, context: context, argsYAML: argsYAML)
        return context.collectDiagnostics()
    }
}

package extension RuleProtocol {
    /// Executes this rule, resolving arguments from raw YAML or falling back to defaults.
    @LintActor
    func execute(file: SourceFileSyntax, context: LintContext, argsYAML: String?) {
        let arguments: Arguments
        if let argsYAML {
            do {
                arguments = try YAMLDecoder().decode(Arguments.self, from: argsYAML)
            } catch {
                logger.warning("Failed to decode args for rule '\(id)': \(error). Using defaults.")
                arguments = defaultArguments
            }
        } else {
            arguments = defaultArguments
        }
        check(file, context, arguments)
    }
}
