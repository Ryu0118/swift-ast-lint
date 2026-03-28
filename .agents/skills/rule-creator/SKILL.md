---
name: rule-creator
description: >
  Create SwiftASTLint lint rules for a user's linter project.
  Covers Rule (no args) and ParameterizedRule (YAML-configurable args) APIs,
  RuleSet composition, YAML config for per-rule args/include/exclude/disabled_rules,
  autofix with SwiftSyntax FixIt, and unit testing with SwiftASTLintTestSupport.
  Use when: user asks to "add a lint rule", "create a rule", "write a rule",
  mentions "SwiftASTLint rule", "lint rule", "AST rule",
  wants to check code patterns via SwiftSyntax,
  or needs help writing Rule closures.
  Also trigger when user says "add a check for...", "detect when...",
  "enforce that...", "ban X in code", or any request about catching
  code patterns at the AST level — even if they don't mention SwiftASTLint.
  Also use when user runs /rule-creator.
---

# Rule Creator for SwiftASTLint

## Orchestration

Your job is to figure out where the user is and guide them to the next step. Be flexible — if they already have everything set up, skip straight to writing the rule. If they're starting from zero, walk them through setup first.

### Step 1: Determine project state

Before writing any code, check the working directory:

1. Look for `Sources/Rules/Rules.swift` and a `Package.swift` that imports SwiftASTLint
2. If found, you know where to create rule files — proceed to Step 2
3. If NOT found, ask the user:

```
I don't see a SwiftASTLint linter project in the current directory.

Where would you like to create rules?
  a) Scaffold a new linter project here (I'll run swiftastlinttool init)
  b) Point me to an existing linter project directory
  c) You're in the wrong directory — cd somewhere else and try again
```

If `swiftastlinttool` isn't installed, explain how to get it:

```
You'll need swiftastlinttool first:
  curl -fsSL https://raw.githubusercontent.com/Ryu0118/swift-ast-lint/main/install.sh | bash
```

The reason we need a proper project is that rules are compiled Swift code — they need a Package.swift with the SwiftSyntax dependency, a Rules module, and a test target. Without this structure, the rule files won't compile.

### Step 2: Understand the rule

Ask what the user wants to detect. Good questions:

- What code pattern should this catch? (get a concrete example)
- Should it be a warning or error?
- Should it be fixable? (can the code be automatically corrected?)
- Does it need configurable thresholds? (→ ParameterizedRule with YAML args)
- Should it apply to all files or specific paths? (→ YAML include/exclude)

If the user already described the rule clearly, skip the questions and start writing.

### Step 3: Write the rule

1. Create a new `.swift` file in `Sources/Rules/` (name it after the rule)
2. Add the rule to the `RuleSet` in `Rules.swift`
3. Write tests in `Tests/RulesTests/`
4. Run `swift test` to verify
5. Optionally configure YAML args/include/exclude in `.swift-ast-lint.yml`

### Step 4: Iterate if needed

If the user says "also catch X" or "that's not quite right", read the existing rule and tests before modifying.

---

## Rule API

### Rule (no arguments)

```swift
Rule(id: "rule-id") { file, context in
    context.report(on: someNode, message: "Description", severity: .warning)
}
```

Severity is specified per-report in the closure. There is no default severity on Rule itself.

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

**Key points:**
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

Finding a rule from RuleSet:

```swift
private let rule: any RuleProtocol
init() throws {
    rule = try #require(rules.find(id: "my-rule"))
}
```

### Testing fix-its with `lintAndFix`

```swift
@Test("fix replaces var with let")
func fixVarToLet() {
    let (diagnostics, fixedSource) = myRule.lintAndFix(source: "var x = 1\n")
    #expect(diagnostics.count == 1)
    #expect(diagnostics[0].isFixable)
    #expect(fixedSource == "let x = 1\n")
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
