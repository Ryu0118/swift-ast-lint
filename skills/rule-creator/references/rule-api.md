# Rule API Reference

## Rule (no arguments)

```swift
Rule(id: "rule-id", description: "Flags XYZ anti-pattern") { file, context in
    context.report(on: someNode, message: "Description", severity: .warning)
}
```

Severity is specified per-report. No default severity on Rule itself.

`description:` is optional (default `nil`) but recommended: it is surfaced by the
`rules` subcommand so agents and tooling can understand the rule without reading its source.

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
- `ParameterizedRule` accepts the same optional `description:` parameter as `Rule`
  (second parameter, before `defaultArguments:`).

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

## Introspection (`rules` subcommand)

Every linter binary built on swift-ast-lint (>= the release containing the `rules` subcommand)
can enumerate its own rules — use this instead of reading `Rules.swift` and the YAML side by side:

```bash
swift run --package-path <linter-path> swift-ast-lint rules                # stable JSON on stdout
swift run --package-path <linter-path> swift-ast-lint rules --format text  # human-readable
swift run --package-path <linter-path> swift-ast-lint rules --config custom.yml
```

JSON entry per rule (registration order, sorted keys):

```json
{
  "id" : "my-rule",
  "description" : "Flags oversized types",
  "parameterized" : true,
  "enabled" : true,
  "default_args" : { "threshold" : 50 },
  "effective_args" : { "threshold" : 30 },
  "include" : [ "Sources/**" ],
  "exclude" : [ "**/*Generated.swift" ]
}
```

- `effective_args` = defaults merged with the YAML `args:` override; compare with `default_args`
  to see what the config actually changes.
- `config_path` at the top level is `null` when no config file was found.
- Use it to check for duplicate rule ids before adding a rule, and to verify YAML config
  took effect after editing it.
