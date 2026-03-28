import SwiftASTLint
import SwiftSyntax

/// Lint rules for the swift-ast-lint project itself.
/// Only rules that require AST analysis beyond SwiftLint's regex capabilities.
public let rules = RuleSet {
    singleLargeTypePerFileRule
    deepNestingRule

    Rule(id: "prefer-string-raw-value-enum") { file, context in
        for stmt in file.statements {
            guard let enumDecl = stmt.item.as(EnumDeclSyntax.self) else { continue }
            checkEnumForRedundantDescription(enumDecl, context: context)
        }
    }
}

@LintActor
private func checkEnumForRedundantDescription(
    _ enumDecl: EnumDeclSyntax,
    context: LintContext,
) {
    // Skip if already has String raw type
    if let inheritedTypes = enumDecl.inheritanceClause?.inheritedTypes {
        let hasStringRaw = inheritedTypes.contains { $0.type.trimmedDescription == "String" }
        if hasStringRaw { return }
    }

    // Collect case names
    let caseNames = enumDecl.memberBlock.members.compactMap { member -> String? in
        guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else { return nil }
        guard caseDecl.elements.count == 1,
              let element = caseDecl.elements.first,
              element.parameterClause == nil
        else { return nil }
        return element.name.text
    }
    guard !caseNames.isEmpty else { return }

    // Look for a description property returning case names as strings
    for member in enumDecl.memberBlock.members {
        guard let varDecl = member.decl.as(VariableDeclSyntax.self),
              let binding = varDecl.bindings.first,
              let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
              pattern.identifier.text == "description",
              let accessor = binding.accessorBlock
        else { continue }

        let body = accessor.trimmedDescription
        let allCasesReturnOwnName = caseNames.allSatisfy { name in
            body.contains(".\(name)") && body.contains("\"\(name)\"")
        }
        if allCasesReturnOwnName {
            let msg = "Enum cases return their own names in description. "
                + "Use String raw value instead of CustomStringConvertible"
            context.report(on: enumDecl, message: msg, severity: .warning)
        }
    }
}
