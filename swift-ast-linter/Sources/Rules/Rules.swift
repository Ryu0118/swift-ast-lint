import SwiftASTLint

/// Lint rules for the swift-ast-lint project itself.
/// Only rules that require AST analysis beyond SwiftLint's regex capabilities.
public let rules = RuleSet {
    singleLargeTypePerFileRule
    deepNestingRule
    preferStringRawValueEnumRule
}
