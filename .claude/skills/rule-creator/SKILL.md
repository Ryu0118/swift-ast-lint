---
name: rule-creator
description: >
  Create, scaffold, and add SwiftASTLint lint rules to a user's linter project.
  Covers Rule/ParameterizedRule API, SwiftSyntax patterns for AST traversal,
  SyntaxVisitor patterns, RuleSet composition, YAML args configuration,
  and unit testing with SwiftASTLintTestSupport.
  Use when: user asks to "add a lint rule", "create a rule", "write a rule",
  mentions "SwiftASTLint rule", "lint rule", "AST rule", wants to check code
  patterns via SwiftSyntax, or needs help writing Rule closures.
  Also use when user runs /rule-creator.
---

# Rule Creator for SwiftASTLint

Create lint rules that run directly against SwiftSyntax AST. No yml abstraction — pure Swift.

## Rule API

### Rule (no arguments)

```swift
import SwiftASTLint
import SwiftSyntax

Rule(id: "rule-id") { file, context in
    // file: SourceFileSyntax — parsed AST of one Swift file
    // context: LintContext — report violations here
    // context.sourceLocationConverter — get line/column from AST nodes
    // context.filePath — absolute path of the file being linted

    context.report(on: someNode, message: "Description", severity: .warning)
    context.report(on: someNode, message: "Critical issue", severity: .error)
}
```

### ParameterizedRule (with YAML-configurable arguments)

```swift
struct MyArgs: Codable, Sendable {
    var threshold: Int = 50      // default value — required
    var maxCount: Int = 3

    enum CodingKeys: String, CodingKey {
        case threshold
        case maxCount = "max_count"  // snake_case for YAML
    }
}

ParameterizedRule(
    id: "my-rule",
    defaultArguments: MyArgs(),
) { file, context, args in
    // args is MyArgs — type-safe, defaults from init, overridable via YAML
    if someCondition(args.threshold) {
        context.report(on: node, message: "...", severity: .warning)
    }
}
```

YAML override (`.swift-ast-lint.yml`):

```yaml
rules:
  my-rule:
    args:
      threshold: 30
      max_count: 5
    include:
      - "Sources/**"
    exclude:
      - "**/*Generated.swift"
```

**Key points:**
- `severity` is always specified in the closure via `context.report(severity:)`. No default severity on Rule.
- `include`/`exclude` are configured in YAML, not in Rule code.
- Args must have default values via `init()`. Rules work without YAML config.

## Two Patterns for Rules

### Pattern 1: Direct AST traversal (simple rules)

```swift
Rule(id: "no-force-try") { file, context in
    for token in file.tokens(viewMode: .sourceAccurate) {
        if token.tokenKind == .keyword(.try),
           token.nextToken(viewMode: .sourceAccurate)?.tokenKind == .exclamationMark
        {
            context.report(on: token, message: "Force try (try!) is not allowed", severity: .error)
        }
    }
}
```

### Pattern 2: SyntaxVisitor (complex rules)

```swift
Rule(id: "max-function-length") { file, context in
    final class Visitor: SyntaxVisitor {
        var violations: [(Syntax, Int)] = []
        let maxLines = 50
        let converter: SourceLocationConverter

        init(converter: SourceLocationConverter) {
            self.converter = converter
            super.init(viewMode: .sourceAccurate)
        }

        override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
            let startLine = converter.location(for: node.positionAfterSkippingLeadingTrivia).line
            let endLine = converter.location(for: node.endPositionBeforeTrailingTrivia).line
            if endLine - startLine + 1 > maxLines {
                violations.append((Syntax(node), endLine - startLine + 1))
            }
            return .visitChildren
        }
    }
    let visitor = Visitor(converter: context.sourceLocationConverter)
    visitor.walk(file)
    for (node, lines) in visitor.violations {
        context.report(on: node, message: "Function is \(lines) lines", severity: .warning)
    }
}
```

**Important**: The Rule closure runs on `@LintActor`. `context.report()` is synchronous — no `await` needed.

## Composing Rules into a RuleSet

```swift
public let rules = RuleSet {
    myParameterizedRule      // ParameterizedRule<MyArgs>
    Rule(id: "simple") { file, ctx in ... }
}
.include(["Sources/**"])     // global include (RuleSet level)
.exclude(["**/*Generated.swift"])
```

## Common SwiftSyntax Patterns

### Get line count of a declaration body

```swift
let converter = context.sourceLocationConverter
let startLine = converter.location(for: decl.memberBlock.leftBrace.positionAfterSkippingLeadingTrivia).line
let endLine = converter.location(for: decl.memberBlock.rightBrace.positionAfterSkippingLeadingTrivia).line
let bodyLines = endLine - startLine - 1
```

### Iterate top-level type declarations

```swift
let types = file.statements.compactMap { stmt -> (any DeclGroupSyntax)? in
    if let cls = stmt.item.as(ClassDeclSyntax.self) { return cls }
    if let str = stmt.item.as(StructDeclSyntax.self) { return str }
    if let enm = stmt.item.as(EnumDeclSyntax.self) { return enm }
    if let act = stmt.item.as(ActorDeclSyntax.self) { return act }
    return nil
}
```

### Check access level

```swift
let isPublic = decl.modifiers.contains { $0.name.tokenKind == .keyword(.public) }
```

## Workflow: Adding a Rule

1. Create a new file in `Sources/Rules/` with the rule definition
2. Add the rule to `RuleSet` in `Rules.swift`
3. **Write unit tests** using `SwiftASTLintTestSupport` (see below)
4. `swift test` to verify
5. Optionally configure YAML args/include/exclude in `.swift-ast-lint.yml`
6. `swift run swift-ast-lint ./path` to test against real code

## Testing a Rule (SwiftASTLintTestSupport)

Import `SwiftASTLintTestSupport` for the `rule.lint(source:)` helper and `ruleSet.find(id:)`.

```swift
@testable import Rules
import SwiftASTLint
import SwiftASTLintTestSupport
import Testing

@Suite("my-rule: description of what the rule checks")
struct MyRuleTests {
    @Test("detects the violation pattern")
    func detectsViolation() async {
        let diagnostics = await myRule.lint(source: "let x = try! foo()")
        #expect(diagnostics.count == 1)
        #expect(diagnostics[0].severity == .error)
    }

    @Test("allows the correct pattern")
    func allowsCorrectPattern() async {
        let diagnostics = await myRule.lint(source: "let x = try foo()")
        #expect(diagnostics.isEmpty)
    }

    @Test("respects YAML args override")
    func argsOverride() async {
        let diagnostics = await myRule.lint(source: "...", argsYAML: "threshold: 10\n")
        #expect(diagnostics.count == 1)
    }
}
```

### Finding a rule from RuleSet

```swift
// In init — use #require to fail fast if rule not found
init() throws {
    rule = try #require(rules.find(id: "my-rule"))
}
```

### Test checklist

- [ ] Violation detected for the target pattern
- [ ] No false positive for similar but valid patterns
- [ ] Edge cases (empty file, nested types, associated values, etc.)
- [ ] YAML args override works (for ParameterizedRule)
- [ ] Severity is correct (warning vs error)
- [ ] Message is descriptive and includes relevant values
- [ ] Parameterized tests (`@Test(arguments:)`) for multiple type kinds or patterns

## CLI Usage

```bash
swift run swift-ast-lint                           # lint cwd
swift run swift-ast-lint ./Sources                  # specific path
swift run swift-ast-lint ./Sources --config cfg.yml # custom config
```

Output: `path:line:col: severity: [rule-id] message` (Xcode/SwiftLint compatible)

Exit codes: 0 (clean), 1 (runtime error), 2 (lint errors found)
