# swift-ast-lint

[![Language](https://img.shields.io/badge/Language-Swift-F05138?style=flat-square)](https://www.swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-lightgrey?style=flat-square)](https://github.com/Ryu0118/swift-ast-lint/releases/latest)
[![License](https://img.shields.io/badge/License-MIT-007ec6?style=flat-square)](LICENSE)

A minimal SwiftSyntax AST-based linting kit. Write lint rules directly in Swift, build your own linter executable, and run it against your codebase.

**Philosophy:** Coding Agents have made yml-based rule abstraction obsolete. SwiftSyntax's API is rich enough to use directly. This package provides only the orchestration layer -- rule registration, file traversal, glob filtering, diagnostics output.

## How It Works

1. `swiftastlinttool init` scaffolds a Swift Package with a linter executable
2. You write lint rules using SwiftSyntax in `Sources/Rules/`
3. `swift run swift-ast-lint ./Sources` runs your rules against your code

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
    Rule(id: "max-nesting-depth", severity: .error) { file, context in
        // Use SwiftSyntax APIs directly
        final class NestingVisitor: SyntaxVisitor {
            var violations: [(Syntax, Int)] = []
            var depth = 0
            let maxDepth = 3
            init() { super.init(viewMode: .sourceAccurate) }
            private func enter(_ node: some SyntaxProtocol) -> SyntaxVisitorContinueKind {
                depth += 1
                if depth > maxDepth { violations.append((Syntax(node), depth)) }
                return .visitChildren
            }
            private func leave() { depth -= 1 }
            override func visit(_ node: IfExprSyntax) -> SyntaxVisitorContinueKind { enter(node) }
            override func visitPost(_ node: IfExprSyntax) { leave() }
            override func visit(_ node: ForStmtSyntax) -> SyntaxVisitorContinueKind { enter(node) }
            override func visitPost(_ node: ForStmtSyntax) { leave() }
        }
        let visitor = NestingVisitor()
        visitor.walk(file)
        for (node, depth) in visitor.violations {
            context.report(on: node, message: "Nesting depth \(depth) exceeds limit of 3")
        }
    }
}
.exclude(["**/*Generated.swift"])
```

Run:

```bash
swift run swift-ast-lint ../my-project/Sources
```

Output (SwiftLint/Xcode compatible):

```
/path/to/File.swift:42:5: error: [max-nesting-depth] Nesting depth 4 exceeds limit of 3
```

## CLI Usage

### Linter (user-side executable)

```bash
swift run swift-ast-lint                              # lint current directory
swift run swift-ast-lint ./Sources                     # lint specific directory
swift run swift-ast-lint ./Sources ./MyModule           # multiple paths
swift run swift-ast-lint ./Sources --config custom.yml  # custom config
```

### Scaffolding tool

```bash
swiftastlinttool init --path ./MyLinter --name MyLinter  # non-interactive
swiftastlinttool init                                     # interactive mode
```

## Configuration

### `.swift-ast-lint.yml`

Optional project-level file path filtering (not rule configuration -- rules are code):

```yaml
included_paths:
  - "Sources/**/*.swift"
excluded_paths:
  - "**/*Generated.swift"
  - ".build/**"
```

### Rule-level filtering

```swift
Rule(
    id: "sources-only-rule",
    severity: .warning,
    include: ["Sources/**"],
    exclude: ["**/*Test*.swift"]
) { file, context in
    // ...
}
```

### RuleSet-level filtering

```swift
let rules = RuleSet {
    // rules...
}
.include(["Sources/**"])
.exclude(["**/*Generated.swift"])
```

Filter priority (intersection -- each level can only narrow):
1. yml `included_paths` / `excluded_paths`
2. RuleSet `.include()` / `.exclude()`
3. Rule `include` / `exclude`

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | No errors (warnings are OK) |
| `1` | Runtime error (file I/O, config parse failure) |
| `2` | Lint errors found (Claude Code hooks compatible) |

## Architecture

| Module | Role |
|--------|------|
| `SwiftASTLint` | Core library: Rule, RuleSet, LintContext, LintCommand, Diagnostic, GlobPattern, Configuration |
| `SwiftASTLintScaffold` | Generates user-side linter packages via `swift package init` |
| `swift-ast-lint-tool` | CLI entry point for scaffolding |

## License

MIT
