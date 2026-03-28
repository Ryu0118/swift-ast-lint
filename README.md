# swift-ast-lint

[![Language](https://img.shields.io/badge/Language-Swift-F05138?style=flat-square)](https://www.swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-lightgrey?style=flat-square)](https://github.com/Ryu0118/swift-ast-lint/releases/latest)
[![License](https://img.shields.io/badge/License-MIT-007ec6?style=flat-square)](LICENSE)

**Build your own Swift linter at the syntax level.**

Create project-specific lint rules programmatically in pure Swift. No YAML, no regex — just the full power of the AST.

## Motivation

SwiftLint is great for common coding style checks, but falls short when you need:

- **Project-specific rules** — Enforce your team's architecture conventions and structural patterns that no generic linter covers.
- **Complex structural checks** — "Every public class over 50 lines must be in its own file" or "No force-try in production code" — rules that require understanding the code structure, not just matching text.
- **AST-level precision** — SwiftLint's custom rules are regex-based. Regex can't distinguish a function call from a comment, a type name from a variable. AST can.

**Why now?** With AI coding assistants, writing SwiftSyntax rules has become dramatically easier. Describe the pattern you want to catch in natural language, and your AI writes the rule. What used to require deep SwiftSyntax expertise is now a simple prompt away.

## How It Works

1. `swiftastlinttool init` scaffolds a Swift Package with a linter executable
2. You write lint rules using SwiftSyntax in `Sources/Rules/`
3. `swift run swift-ast-lint ./Sources` runs your rules against your code
4. `swift run swift-ast-lint --fix ./Sources` auto-fixes what it can

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Ryu0118/swift-ast-lint/main/install.sh | bash
```

### Other methods

#### Nest ([mtj0928/nest](https://github.com/mtj0928/nest))

```bash
nest install Ryu0118/swift-ast-lint
```

#### Mise ([jdx/mise](https://github.com/jdx/mise))

```bash
mise use -g ubi:Ryu0118/swift-ast-lint
```

#### Build from source

Requires Swift 6.0+ and macOS 15+.

```bash
git clone https://github.com/Ryu0118/swift-ast-lint.git
cd swift-ast-lint
swift build
```

## Quick Start

```bash
# Scaffold a new linter project
swiftastlinttool init --path ./MyLinter --name MyLinter
cd MyLinter
```

Edit `Sources/Rules/Rules.swift`:

```swift
import SwiftASTLint
import SwiftSyntax

public let rules = RuleSet {
    Rule(id: "deep-nesting") { file, context in
        checkNesting(in: Syntax(file), depth: 0, context: context)
    }
}

@LintActor
private func checkNesting(in node: Syntax, depth: Int, context: LintContext) {
    for child in node.children(viewMode: .sourceAccurate) {
        let isControlFlow = child.is(IfExprSyntax.self)
            || child.is(GuardStmtSyntax.self)
            || child.is(ForStmtSyntax.self)
            || child.is(WhileStmtSyntax.self)
        let newDepth = isControlFlow ? depth + 1 : depth
        if isControlFlow, newDepth >= 4 {
            context.report(
                on: child,
                message: "Control flow nested \(newDepth) levels deep. Extract a helper function.",
                severity: .error,
            )
        }
        checkNesting(in: child, depth: newDepth, context: context)
    }
}
```

Run:

```bash
swift run swift-ast-lint ../my-project/Sources
```

Output (SwiftLint/Xcode compatible):

```
/path/to/File.swift:42:9: error: [deep-nesting] Control flow nested 4 levels deep. Extract a helper function.
```

## Rule API

### Rule (no arguments)

Severity is specified per-report in the closure, not on the Rule itself:

```swift
Rule(id: "rule-id") { file, context in
    context.report(on: someNode, message: "Description", severity: .warning)
}
```

### ParameterizedRule (YAML-configurable arguments)

```swift
struct ThresholdArgs: Codable, Sendable {
    var threshold: Int = 50
}

ParameterizedRule(id: "large-type", defaultArguments: ThresholdArgs()) { file, context, args in
    // args.threshold is 50 by default, overridable via YAML
    context.report(on: node, message: "Type too large", severity: .warning)
}
```

### Rules with autofix

Rules can provide fix-its using SwiftSyntax's `FixIt` type. When the user runs `--fix`, these are applied automatically:

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

Rules without fix-its use `context.report()` as before — fully backward compatible.

### RuleSet

```swift
public let rules = RuleSet {
    myParameterizedRule
    Rule(id: "simple") { file, ctx in ... }
}
```

## CLI Usage

### Linter (user-side executable)

```bash
swift run swift-ast-lint                              # lint current directory
swift run swift-ast-lint ./Sources                     # lint specific directory
swift run swift-ast-lint ./Sources ./MyModule           # multiple paths
swift run swift-ast-lint ./Sources --config custom.yml  # custom config
swift run swift-ast-lint --fix ./Sources                # apply autofixes
```

### Scaffolding tool

```bash
swiftastlinttool init --path ./MyLinter --name MyLinter  # non-interactive
swiftastlinttool init                                     # interactive mode
```

## Configuration

### `.swift-ast-lint.yml`

Optional YAML file for path filtering and per-rule configuration:

```yaml
# Project-level path filtering
included_paths:
  - "Sources/**/*.swift"
excluded_paths:
  - "**/*Generated.swift"
  - ".build/**"

# Disable specific rules entirely
disabled_rules:
  - "no-force-try"

# Per-rule configuration
rules:
  large-type:
    args:
      threshold: 30           # Override ParameterizedRule defaults
    include:
      - "Sources/**"          # Only apply this rule to Sources/
    exclude:
      - "**/*Generated.swift" # Skip generated files for this rule
```

### Filter priority

Rules are filtered in this order:

1. **`disabled_rules`** — rules listed here are skipped entirely
2. **`included_paths` / `excluded_paths`** — project-wide file filtering
3. **Per-rule `include` / `exclude`** in the `rules:` YAML section — per-rule file filtering

Each level can only narrow, never widen. Rules not listed in `rules:` apply to all files that pass step 2.

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | No errors (warnings are OK) |
| `1` | Runtime error (file I/O, config parse failure) |
| `2` | Lint errors found (Claude Code hooks compatible) |

## License

MIT
