---
name: rule-creator
description: >
  Create, scaffold, and add SwiftASTLint lint rules to a user's linter project.
  Covers Rule API usage, SwiftSyntax patterns for AST traversal, SyntaxVisitor
  patterns, include/exclude glob filtering, and RuleSet composition.
  Use when: user asks to "add a lint rule", "create a rule", "write a rule",
  mentions "SwiftASTLint rule", "lint rule", "AST rule", wants to check code
  patterns via SwiftSyntax, or needs help writing Rule closures.
  Also use when user runs /rule-creator.
---

# Rule Creator for SwiftASTLint

Create lint rules that run directly against SwiftSyntax AST. No yml abstraction — pure Swift.

## Rule API

```swift
import SwiftASTLint
import SwiftSyntax

Rule(
    id: "rule-id",              // Unique kebab-case identifier
    severity: .warning,          // .warning or .error
    include: ["Sources/**"],     // Optional glob patterns (empty = all files)
    exclude: ["**/*Generated.swift"],
    check: { file, context in    // @Sendable @LintActor closure
        // file: SourceFileSyntax — parsed AST of one Swift file
        // context: LintContext — report violations here
        // context.sourceLocationConverter — get line/column from AST nodes
        // context.filePath — absolute path of the file being linted

        context.report(on: someNode, message: "Description of violation")
        context.report(on: someNode, message: "Custom severity", severity: .error)
    }
)
```

## Two Patterns for Rules

### Pattern 1: Direct AST traversal (simple rules)

Iterate `file.statements` or use SwiftSyntax query APIs directly.

```swift
Rule(id: "no-force-try", severity: .error) { file, context in
    for token in file.tokens(viewMode: .sourceAccurate) {
        if token.tokenKind == .keyword(.try),
           token.nextToken(viewMode: .sourceAccurate)?.tokenKind == .exclamationMark
        {
            context.report(on: token, message: "Force try (try!) is not allowed")
        }
    }
}
```

### Pattern 2: SyntaxVisitor (complex rules)

Define a visitor class inside the closure. Collect violations synchronously, then report.

```swift
Rule(id: "max-function-length", severity: .warning) { file, context in
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
            let lineCount = endLine - startLine + 1
            if lineCount > maxLines {
                violations.append((Syntax(node), lineCount))
            }
            return .visitChildren
        }
    }
    let visitor = Visitor(converter: context.sourceLocationConverter)
    visitor.walk(file)
    for (node, lines) in visitor.violations {
        context.report(on: node, message: "Function is \(lines) lines (max \(visitor.maxLines))")
    }
}
```

**Important**: The Rule closure runs on `@LintActor`. `context.report()` is synchronous — no `await` needed. SyntaxVisitor is also synchronous. Collect violations in the visitor, then report after `walk()`.

## Composing Rules into a RuleSet

```swift
public let rules = RuleSet {
    noForceTryRule()
    maxFunctionLengthRule()
}
.include(["Sources/**"])
.exclude(["**/*Generated.swift", "**/*Mock.swift"])
```

## Common SwiftSyntax Patterns

### Check access level

```swift
let isPublic = decl.modifiers.contains { $0.name.tokenKind == .keyword(.public) }
```

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

## Workflow: Adding a Rule

1. Create a new function in `Sources/Rules/` returning `Rule`
2. Add the function call to the `RuleSet` in `Rules.swift`
3. Write tests with `@LintActor` and `Parser.parse(source:)`
4. `swift test` to verify
5. `swift run swift-ast-lint ./path` to test against real code

## Testing a Rule

```swift
@Test("detects violation")
@LintActor
func detectsViolation() {
    let source = "let x: Int = try! something()"
    let file = Parser.parse(source: source)
    let converter = SourceLocationConverter(fileName: "test.swift", tree: file)
    let context = LintContext(
        filePath: "test.swift",
        sourceLocationConverter: converter,
        ruleID: "test",
        defaultSeverity: .error
    )
    myRule().check(file, context)
    #expect(context.collectDiagnostics().count == 1)
}
```

## CLI Usage

```bash
swift run swift-ast-lint                           # lint cwd
swift run swift-ast-lint ./Sources                  # specific path
swift run swift-ast-lint ./Sources --config cfg.yml # custom config
```

Output: `path:line:col: severity: [rule-id] message` (Xcode/SwiftLint compatible)

Exit codes: 0 (clean), 1 (runtime error), 2 (lint errors found)
