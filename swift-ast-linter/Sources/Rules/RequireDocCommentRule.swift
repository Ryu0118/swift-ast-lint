import SwiftASTLint
import SwiftSyntax

struct RequireDocCommentArgs: Codable {
    var minLines: Int = 50

    enum CodingKeys: String, CodingKey {
        case minLines = "min_lines"
    }
}

/// Reports functions/methods with `minLines` or more lines that lack a doc comment (`///` or `/** */`).
let requireDocCommentRule = ParameterizedRule(
    id: "require-doc-comment",
    defaultArguments: RequireDocCommentArgs(),
) { file, context, args in
    for stmt in file.statements {
        checkForDocComment(in: Syntax(stmt), context: context, minLines: args.minLines)
    }
}

private func checkForDocComment(
    in node: Syntax,
    context: LintContext,
    minLines: Int,
) {
    if let funcDecl = node.as(FunctionDeclSyntax.self) {
        checkFunction(funcDecl, context: context, minLines: minLines)
    }
    for child in node.children(viewMode: .sourceAccurate) {
        checkForDocComment(in: child, context: context, minLines: minLines)
    }
}

private func checkFunction(
    _ funcDecl: FunctionDeclSyntax,
    context: LintContext,
    minLines: Int,
) {
    guard let body = funcDecl.body else { return }
    let converter = context.sourceLocationConverter
    let startLine = converter.location(for: body.leftBrace.positionAfterSkippingLeadingTrivia).line
    let endLine = converter.location(for: body.rightBrace.positionAfterSkippingLeadingTrivia).line
    let bodyLines = endLine - startLine - 1
    guard bodyLines >= minLines else { return }
    guard !funcDecl.hasDocComment else { return }
    context.report(
        on: funcDecl,
        message: "Function '\(funcDecl.name.text)' is \(bodyLines) lines but has no doc comment.",
        severity: .error,
    )
}

private extension FunctionDeclSyntax {
    var hasDocComment: Bool {
        for piece in leadingTrivia {
            switch piece {
            case .docLineComment, .docBlockComment:
                return true
            default:
                continue
            }
        }
        return false
    }
}
