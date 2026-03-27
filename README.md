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
    Rule(id: "no-force-try", severity: .error) { file, context in
        for token in file.tokens(viewMode: .sourceAccurate) {
            if token.tokenKind == .keyword(.try),
               token.nextToken(viewMode: .sourceAccurate)?.tokenKind == .exclamationMark
            {
                context.report(on: token, message: "Force try (try!) is not allowed")
            }
        }
    }

    Rule(
        id: "single-large-public-type-per-file",
        severity: .error,
        exclude: ["**/*Generated.swift"]
    ) { file, context in
        let types = file.statements.compactMap { stmt -> (any DeclGroupSyntax)? in
            if let cls = stmt.item.as(ClassDeclSyntax.self) { return cls }
            if let str = stmt.item.as(StructDeclSyntax.self) { return str }
            if let enm = stmt.item.as(EnumDeclSyntax.self) { return enm }
            return nil
        }
        let largePublicTypes = types.filter { decl in
            let isPublic = decl.modifiers.contains {
                $0.name.tokenKind == .keyword(.public) || $0.name.tokenKind == .keyword(.package)
            }
            guard isPublic else { return false }
            let converter = context.sourceLocationConverter
            let start = converter.location(for: decl.memberBlock.leftBrace.positionAfterSkippingLeadingTrivia).line
            let end = converter.location(for: decl.memberBlock.rightBrace.positionAfterSkippingLeadingTrivia).line
            return (end - start - 1) >= 50
        }
        guard largePublicTypes.count > 1 else { return }
        for decl in largePublicTypes {
            context.report(on: decl, message: "Split this file: too many large public types")
        }
    }
}
```

Run:

```bash
swift run swift-ast-lint ../my-project/Sources
```

Output (SwiftLint/Xcode compatible):

```
/path/to/File.swift:42:5: error: [no-force-try] Force try (try!) is not allowed
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

## License

MIT
