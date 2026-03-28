# Testing Guide for SwiftASTLint Rules

## Design principles

**Test what it must NOT catch, not just what it must catch.** A lint rule that flags everything is useless. False positive tests are equally important as violation tests — they prove the rule is precise.

**Boundary values first.** For ParameterizedRule with thresholds, always test:
- Below threshold (no violation)
- At threshold (violation triggers)
- Above threshold (still a violation)

**One behavior per test.** Each `@Test` should verify a single scenario. When a test fails, the name alone should tell you what broke.

**Test names describe behavior, not implementation.** Good: `"error at depth 4 with default max 4"`. Bad: `"testDeepNesting"`. The name should state the input condition and the expected outcome.

**Parameterized tests for variant coverage.** Use `@Test(arguments:)` when the same assertion applies to multiple inputs (e.g. all control flow types, all access levels). Each argument should be a meaningful variant, not just padding.

**Edge cases are not optional:**
- Empty file (zero input)
- Single-line file
- The rule's pattern appearing in a context where it should NOT trigger (comments, strings, nested types, separate scopes)
- State reset between functions/types (depth, counters, etc.)

## API

Import `SwiftASTLintTestSupport` for `rule.lint(source:)`, `rule.lintAndFix(source:)`, and `ruleSet.find(id:)`.

### Basic structure

```swift
@testable import Rules
import SwiftASTLint
import SwiftASTLintTestSupport
import Testing

@Suite("deep-nesting: detects control flow nested beyond max depth via AST")
struct DeepNestingRuleTests {
    // ...
}
```

`@Suite` description should state `"<rule-id>: <what it checks>"`.

### Finding a rule from RuleSet

```swift
private let rule: any RuleProtocol
init() throws {
    rule = try #require(rules.find(id: "my-rule"))
}
```

### Violation test (the rule fires)

```swift
@Test("error at depth 4 with default max 4")
func atThreshold() async {
    let source = """
    func foo() {
        if true {
            if true {
                if true {
                    if true { let _ = 0 }
                }
            }
        }
    }
    """
    let diagnostics = await deepNestingRule.lint(source: source)
    #expect(diagnostics.count == 1)
    #expect(diagnostics[0].severity == .error)
}
```

### False positive test (the rule must NOT fire)

These are equally important as violation tests. Prove the rule does not flag valid code that looks similar to the target pattern.

```swift
@Test("flat control flow at same level does not accumulate depth")
func flatSameLevel() async {
    let source = """
    func foo() {
        if true { let _ = 0 }
        if true { let _ = 0 }
        if true { let _ = 0 }
    }
    """
    let diagnostics = await deepNestingRule.lint(source: source)
    #expect(diagnostics.isEmpty)
}

@Test("depth resets between separate functions")
func depthResetsBetweenFunctions() async {
    let source = """
    func foo() {
        if true { if true { if true { let _ = 0 } } }
    }
    func bar() {
        if true { if true { if true { let _ = 0 } } }
    }
    """
    let diagnostics = await deepNestingRule.lint(source: source)
    #expect(diagnostics.isEmpty)
}
```

### Boundary value test

For ParameterizedRule with thresholds — test the exact boundary:

```swift
// Just below: no violation
@Test("no diagnostic at depth 3 with default max 4")
func belowThreshold() async { ... }

// Exactly at: violation
@Test("error at depth 4 with default max 4")
func atThreshold() async { ... }
```

### YAML args override test

```swift
@Test("YAML args override max depth", arguments: [
    ("max_depth: 2\n", 1),
    ("max_depth: 10\n", 0),
])
func yamlOverride(yaml: String, expectedCount: Int) async {
    let source = """
    func foo() {
        if true {
            if true { let _ = 0 }
        }
    }
    """
    let diagnostics = await deepNestingRule.lint(source: source, argsYAML: yaml)
    #expect(diagnostics.count == expectedCount)
}
```

### Parameterized variant test

When a rule should detect multiple syntax forms (all control flow types, all access levels, etc.):

```swift
@Test("detects all control flow types", arguments: [
    "if true { let _ = 0 }",
    "guard true else { return }",
    "for _ in [] { let _ = 0 }",
    "while true { let _ = 0 }",
    "switch 0 { default: let _ = 0 }",
    "do { let _ = 0 }",
])
func allControlFlowTypes(statement: String) async {
    let source = """
    func foo() {
        if true { for _ in [1] { while true { \(statement) } } }
    }
    """
    let diagnostics = await deepNestingRule.lint(source: source)
    #expect(!diagnostics.isEmpty, "Expected violation for: \(statement)")
}
```

### Fix-it test

```swift
@Test("fix replaces var with let")
func fixVarToLet() {
    let (diagnostics, fixedSource) = myRule.lintAndFix(source: "var x = 1\n")
    #expect(diagnostics.count == 1)
    #expect(diagnostics[0].isFixable)
    #expect(fixedSource == "let x = 1\n")
}
```

### Edge case test

```swift
@Test("empty file produces no diagnostics")
func emptyFile() async {
    let diagnostics = await deepNestingRule.lint(source: "")
    #expect(diagnostics.isEmpty)
}
```

## Coverage checklist

Every rule must have tests for:

1. **Violation** — target pattern detected with correct severity
2. **False positive** — similar but valid patterns produce no diagnostic
3. **Boundary** — threshold ± 1 (for ParameterizedRule)
4. **Edge cases** — empty file, single-line, nested scopes, separate functions
5. **YAML args** — override changes behavior (for ParameterizedRule)
6. **Parameterized variants** — `@Test(arguments:)` for multiple type/syntax kinds
7. **Fix-it output** — correct source after fix (for fixable rules)
8. **Message content** — diagnostic message includes relevant context
