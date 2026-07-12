import Foundation
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

    /// Human-readable summary of what this rule detects. Surfaced by the `rules` subcommand.
    /// Defaults to `nil`.
    var description: String? { get }

    /// Default arguments used when no YAML override is provided.
    var defaultArguments: Arguments { get }

    /// Checks a source file and reports diagnostics via the context.
    func check(_ file: SourceFileSyntax, _ context: LintContext, _ arguments: Arguments)
}

public extension RuleProtocol {
    /// Rules without an explicit description report `nil`.
    var description: String? { nil }

    /// Whether this rule takes configurable arguments (i.e. its ``Arguments`` type is not
    /// ``EmptyArguments``).
    var isParameterized: Bool { Arguments.self != EmptyArguments.self }

    /// Executes this rule, resolving arguments from raw YAML or falling back to defaults.
    func execute(file: SourceFileSyntax, context: LintContext, argsYAML: String?) {
        execute(file: file, context: context, preDecodedArgs: decodeArguments(from: argsYAML))
    }
}

package extension RuleProtocol {
    /// Decodes this rule's arguments from raw YAML, returning them as a type-erased ``Sendable``.
    ///
    /// Used to pre-decode arguments once per lint run so that YAML decoding is not repeated for every file.
    func decodeArguments(from argsYAML: String?) -> any Sendable {
        guard let argsYAML else { return defaultArguments }
        do {
            return try YAMLDecoder().decode(Arguments.self, from: argsYAML)
        } catch {
            logger.warning("Failed to decode args for rule '\(id)': \(error). Using defaults.")
            return defaultArguments
        }
    }

    /// Executes this rule using pre-decoded arguments, falling back to defaults if the type does not match.
    func execute(file: SourceFileSyntax, context: LintContext, preDecodedArgs: any Sendable) {
        guard let args = preDecodedArgs as? Arguments else {
            assertionFailure("Pre-decoded args type mismatch for rule '\(id)' — this is a programming error")
            check(file, context, defaultArguments)
            return
        }
        check(file, context, args)
    }

    /// Encodes the arguments resolved from raw YAML (or the defaults when the YAML is absent or
    /// invalid) as a JSON-serializable object. Used by the `rules` subcommand report.
    func resolvedArgumentsJSONObject(argsYAML: String?) throws -> Any {
        let resolved = decodeArguments(from: argsYAML) as? Arguments ?? defaultArguments
        let data = try JSONEncoder().encode(resolved)
        return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }
}
