# Rule API Reference

## Rule (no arguments)

```swift
Rule(id: "rule-id") { file, context in
    context.report(on: someNode, message: "Description", severity: .warning)
}
```

Severity is specified per-report. No default severity on Rule itself.

## Rule with autofix

```swift
import SwiftDiagnostics

Rule(id: "var-to-let") { file, context in
    for stmt in file.statements {
        guard let varDecl = stmt.item.as(VariableDeclSyntax.self) else { continue }
        let keyword = varDecl.bindingSpecifier
        guard keyword.tokenKind == .keyword(.var) else { continue }
        let newKeyword = keyword.with(\.tokenKind, .keyword(.let))
        context.reportWithFix(
            on: varDecl,
            message: "Use let instead of var",
            severity: .warning,
            fixIts: [
                FixIt.replace(
                    message: SimpleFixItMessage("Replace var with let"),
                    oldNode: keyword,
                    newNode: newKeyword,
                ),
            ],
        )
    }
}
```

**Fix API:**
- `context.reportWithFix(on:message:severity:fixIts:)` — report + attach fix-its
- `FixIt.replace(message:oldNode:newNode:)` — node replacement
- `FixIt(message:changes:)` — multi-change: `.replace`, `.replaceLeadingTrivia`, `.replaceTrailingTrivia`, `.replaceText`
- `SimpleFixItMessage("description")` — simple FixItMessage implementation
- `context.report()` — unfixable violations (backward compatible)

## ParameterizedRule (YAML-configurable arguments)

```swift
struct MyArgs: Codable, Sendable {
    var threshold: Int = 50  // default value required
    enum CodingKeys: String, CodingKey {
        case threshold
    }
}

ParameterizedRule(id: "my-rule", defaultArguments: MyArgs()) { file, context, args in
    if condition(args.threshold) {
        context.report(on: node, message: "...", severity: .warning)
    }
}
```

- `include`/`exclude` belong in YAML only, not in Rule code.
- Args must have defaults via `init()`. Rules work without YAML.

## RuleSet

```swift
public let rules = RuleSet {
    myParameterizedRule
    Rule(id: "simple") { file, ctx in ... }
}
```

## YAML Config (`.swift-ast-lint.yml`)

```yaml
disabled_rules:
  - "deprecated-rule"

rules:
  my-rule:
    args:
      threshold: 30
    include:
      - "Sources/**"
    exclude:
      - "**/*Generated.swift"
```

Rules not listed use defaults. Rules in `disabled_rules` are skipped entirely.
