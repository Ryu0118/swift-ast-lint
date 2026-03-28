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

Determine where the user is and guide them to the next step. If they already have a linter project set up, skip straight to writing rules.

### Step 1: Determine project state

Check the working directory for `Sources/Rules/Rules.swift` and a `Package.swift` that imports SwiftASTLint.

- **Found** — proceed to Step 2.
- **Not found** — ask the user before scaffolding:
  1. Package name (default: MyLinter)
  2. Output path (default: `./<name>` — uses the package name from question 1)
  3. macOS deployment target (e.g. v13, v14, v15 — default: v15)

**Wait for answers before proceeding.** When the user answers the path question with the same value as the package name, treat it as `./<that-name>`. The `--path` flag must always be the **directory path**, and `--name` must always be the **package name**. Example: if name is "ASTLinter" and path answer is "ASTLinter", run `--path ./ASTLinter --name ASTLinter`.

```bash
swiftastlinttool init --path <path> --name <name>
```

The scaffold adds `platforms: [.macOS(.v15)]` automatically. If the user chose a different macOS version (e.g. v13, v14), patch `Package.swift` to replace `.v15` with the chosen version.

If `swiftastlinttool` is not installed:

```
curl -fsSL https://raw.githubusercontent.com/Ryu0118/swift-ast-lint/main/install.sh | bash
```

### Step 2: Understand the rule

If the user already described the rule clearly, skip questions and start writing. Otherwise ask:

- What code pattern should this catch? (concrete example)
- Warning or error?
- Fixable? (auto-correct via FixIt)
- Configurable thresholds? (→ ParameterizedRule)
- Specific file paths? (→ YAML include/exclude)

### Step 3: Write the rule

1. Create `.swift` file in `Sources/Rules/`
2. Register in `RuleSet` in `Rules.swift`
3. Write tests in `Tests/RulesTests/`
4. Run `swift test` to verify

For API reference, see [references/rule-api.md](references/rule-api.md). For test design principles and examples, see [references/testing-guide.md](references/testing-guide.md).

### Step 4: YAML configuration

After writing the rule, ask whether to add YAML config to `.swift-ast-lint.yml`:

- `args` — override ParameterizedRule defaults (thresholds, limits, etc.)
- `include` / `exclude` — restrict rule to specific file paths (glob)
- `disabled_rules` — disable a rule entirely

Example:

```yaml
rules:
  deep-nesting:
    args:
      max_depth: 5
    include:
      - "Sources/**"
    exclude:
      - "**/*Generated.swift"
```

If the user declines, move on.

### Step 5: Iterate if needed

If the user says "also catch X" or "that's not quite right", read the existing rule and tests before modifying.

### Step 6: Setup guide (new projects only)

**Skip this step if the user pointed to an existing project (not scaffolded in Step 1).**

After all rules pass tests, explain how to run lint and offer automation options. Present in a way that someone unfamiliar with the tooling can understand:

```
Lint is ready. Here's how to run it:

  swift run --package-path <linter-path> swift-ast-lint <target-path>

This builds the linter and checks your code. First run takes a while
(compiling SwiftSyntax), but subsequent runs are fast.

Want to automate this? Options:

  a) Build cache script — saves a hash of your rule files. If nothing
     changed since last run, skips the build entirely and runs the
     cached binary directly. Makes repeated lint runs near-instant.

  b) Makefile — adds `make ast-lint` so you can run it with one command.
     Pairs well with (a).

  c) Claude Code hooks / git pre-commit — automatically runs lint
     before every commit, so violations are caught before they land.

  d) None — I'll just run it manually.
```

Wait for answer, then set up what they chose. See [references/setup-guide.md](references/setup-guide.md) for templates.
