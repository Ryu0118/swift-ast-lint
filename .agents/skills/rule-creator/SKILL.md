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

## Orchestration

When invoked, first figure out where the user is and guide them through the right steps:

### 1. No linter project exists

If there is no `Sources/Rules/` directory, no `Package.swift` importing SwiftASTLint, or the user is in an unrelated directory:

Tell the user they need to scaffold a linter project first:

```
To add lint rules, you first need a linter project.
Run these commands to get started:

  swiftastlinttool init --path ./MyLinter --name MyLinter
  cd MyLinter

Then come back and ask me to create the rule!
```

If `swiftastlinttool` is not installed, also tell them how to install it:

```
First install swiftastlinttool:
  curl -fsSL https://raw.githubusercontent.com/Ryu0118/swift-ast-lint/main/install.sh | bash

Then scaffold your linter:
  swiftastlinttool init --path ./MyLinter --name MyLinter
  cd MyLinter
```

Do NOT attempt to create rule files without a valid linter project.

### 2. Linter project exists, ready to add rules

If `Sources/Rules/Rules.swift` and `Package.swift` (with SwiftASTLint dependency) exist, proceed to create the rule:

1. Understand what the user wants to detect
2. Write the rule in a new file under `Sources/Rules/`
3. Add it to the `RuleSet` in `Rules.swift`
4. Write tests in `Tests/RulesTests/`
5. Run `swift test` to verify
6. Optionally configure YAML args/include/exclude

### 3. Modifying an existing rule

If the user references a rule that already exists, read its current implementation and tests before making changes.

---

## Rule API

### Rule (no arguments)

```swift
Rule(id: "rule-id") { file, context in
    context.report(on: someNode, message: "Description", severity: .warning)
}
```

### Rule with autofix

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
- `context.reportWithFix(on:message:severity:fixIts:)` — reports + attaches fix-its
- `FixIt.replace(message:oldNode:newNode:)` — convenience for node replacement
- `FixIt(message:changes:)` — multi-change: `.replace`, `.replaceLeadingTrivia`, `.replaceTrailingTrivia`, `.replaceText`
- `SimpleFixItMessage("description")` — simple FixItMessage implementation
- Rules without fix-its use `context.report()` as before (fully backward compatible)

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
```

## YAML Config (`.swift-ast-lint.yml`)

```yaml
# Disable specific rules entirely
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

Rules not listed use defaults. No need to declare every rule.
Rules in `disabled_rules` are skipped entirely regardless of other config.

## Workflow

1. Create a new `.swift` file in `Sources/Rules/`
2. Add the rule to `RuleSet` in `Rules.swift`
3. Write unit tests using `SwiftASTLintTestSupport` (see below)
4. `swift test` to verify
5. Optionally configure YAML args/include/exclude
6. `swift run swift-ast-lint ./path` to test on real code

## Testing with SwiftASTLintTestSupport

Import `SwiftASTLintTestSupport` for `rule.lint(source:)`, `rule.lintAndFix(source:)`, and `ruleSet.find(id:)`.

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

### Testing fix-its with `lintAndFix`

```swift
@Test("fix replaces var with let")
@LintActor
func fixVarToLet() {
    let (diagnostics, fixedSource) = myRule.lintAndFix(source: "var x = 1\n")
    #expect(diagnostics.count == 1)
    #expect(diagnostics[0].isFixable)
    #expect(fixedSource == "let x = 1\n")
}

@Test("non-fixable violation returns nil fixedSource")
@LintActor
func nonFixable() {
    let (_, fixedSource) = myRule.lintAndFix(source: "let x = 1\n")
    #expect(fixedSource == nil)
}
```

### Test checklist

- Violation detected for target pattern
- No false positive for similar valid patterns
- Edge cases (empty file, nested types, etc.)
- YAML args override (for ParameterizedRule)
- Correct severity (warning vs error)
- Parameterized tests (`@Test(arguments:)`) for multiple type kinds
- Fix-it produces correct output (for fixable rules)
- Non-fixable cases return nil fixedSource
