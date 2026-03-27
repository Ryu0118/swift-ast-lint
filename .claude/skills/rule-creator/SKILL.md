---
name: rule-creator
description: >
  Create SwiftASTLint lint rules for a user's linter project.
  Covers Rule (no args) and ParameterizedRule (YAML-configurable args) APIs,
  RuleSet composition, YAML config for per-rule args/include/exclude,
  and unit testing with SwiftASTLintTestSupport.
  Use when: user asks to "add a lint rule", "create a rule", "write a rule",
  mentions "SwiftASTLint rule", "lint rule", "AST rule",
  wants to check code patterns via SwiftSyntax,
  or needs help writing Rule closures.
  Also use when user runs /rule-creator.
---

# Rule Creator for SwiftASTLint

## Rule API

### Rule (no arguments)

```swift
Rule(id: "rule-id") { file, context in
    context.report(on: someNode, message: "Description", severity: .warning)
}
```

### ParameterizedRule (YAML-configurable arguments)

```swift
struct MyArgs: Codable, Sendable {
    var threshold: Int = 50  // default value required
    enum CodingKeys: String, CodingKey {
        case threshold  // snake_case for YAML keys if needed
    }
}

ParameterizedRule(id: "my-rule", defaultArguments: MyArgs()) { file, context, args in
    if condition(args.threshold) {
        context.report(on: node, message: "...", severity: .warning)
    }
}
```

**Key rules:**
- `severity` is always specified per-report in the closure. No default severity on Rule.
- `include`/`exclude` are in YAML only, not in Rule code.
- Args must have defaults via `init()`. Rules work without YAML.

### RuleSet

```swift
public let rules = RuleSet {
    myParameterizedRule
    Rule(id: "simple") { file, ctx in ... }
}
.include(["Sources/**"])
.exclude(["**/*Generated.swift"])
```

## YAML Config (`.swift-ast-lint.yml`)

```yaml
rules:
  my-rule:
    args:
      threshold: 30
    include:
      - "Sources/**"
    exclude:
      - "**/*Generated.swift"
```

Rules not listed use defaults. No need to declare every rule.

## Workflow

1. Create a new `.swift` file in `Sources/Rules/`
2. Add the rule to `RuleSet` in `Rules.swift`
3. Write unit tests using `SwiftASTLintTestSupport` (see below)
4. `swift test` to verify
5. Optionally configure YAML args/include/exclude
6. `swift run swift-ast-lint ./path` to test on real code

## Testing with SwiftASTLintTestSupport

Import `SwiftASTLintTestSupport` for `rule.lint(source:)` and `ruleSet.find(id:)`.

```swift
@testable import Rules
import SwiftASTLint
import SwiftASTLintTestSupport
import Testing

@Suite("my-rule: what it checks")
struct MyRuleTests {
    @Test("detects violation")
    func detectsViolation() async {
        let diagnostics = await myRule.lint(source: "let x = try! foo()")
        #expect(diagnostics.count == 1)
        #expect(diagnostics[0].severity == .error)
    }

    @Test("allows correct pattern")
    func allowsCorrect() async {
        let diagnostics = await myRule.lint(source: "let x = try foo()")
        #expect(diagnostics.isEmpty)
    }

    @Test("YAML args override")
    func argsOverride() async {
        let diagnostics = await myRule.lint(source: "...", argsYAML: "threshold: 10\n")
        #expect(diagnostics.count == 1)
    }
}
```

Finding a rule from RuleSet (use `init() throws` with `#require`):

```swift
private let rule: any RuleProtocol
init() throws {
    rule = try #require(rules.find(id: "my-rule"))
}
```

### Test checklist

- Violation detected for target pattern
- No false positive for similar valid patterns
- Edge cases (empty file, nested types, etc.)
- YAML args override (for ParameterizedRule)
- Correct severity (warning vs error)
- Parameterized tests (`@Test(arguments:)`) for multiple type kinds
