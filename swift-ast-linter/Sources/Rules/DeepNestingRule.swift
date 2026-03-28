import SwiftASTLint
import SwiftSyntax

struct DeepNestingArgs: Codable {
    var maxDepth: Int = 4

    enum CodingKeys: String, CodingKey {
        case maxDepth = "max_depth"
    }
}

/// Reports control flow statements (if, guard, for, while, switch, do) nested deeper than `maxDepth`.
let deepNestingRule = ParameterizedRule(
    id: "deep-nesting",
    defaultArguments: DeepNestingArgs(),
) { file, context, args in
    checkNesting(in: Syntax(file), depth: 0, maxDepth: args.maxDepth, context: context)
}

@LintActor
private func checkNesting(
    in node: Syntax,
    depth: Int,
    maxDepth: Int,
    context: LintContext,
) {
    for child in node.children(viewMode: .sourceAccurate) {
        let isControlFlow = child.isControlFlowNode
        let newDepth = isControlFlow ? depth + 1 : depth

        if isControlFlow, newDepth >= maxDepth {
            context.report(
                on: child,
                message: "Control flow nested \(newDepth) levels deep (max \(maxDepth)). Extract a helper function.",
                severity: .error,
            )
        }
        checkNesting(in: child, depth: newDepth, maxDepth: maxDepth, context: context)
    }
}

private extension Syntax {
    var isControlFlowNode: Bool {
        self.is(IfExprSyntax.self)
            || self.is(GuardStmtSyntax.self)
            || self.is(ForStmtSyntax.self)
            || self.is(WhileStmtSyntax.self)
            || self.is(SwitchExprSyntax.self)
            || self.is(DoStmtSyntax.self)
    }
}
