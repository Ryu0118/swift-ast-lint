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
  2. Output path (default: `./<name>`)
  3. macOS deployment target (e.g. v13, v14, v15 — default: v15)

**Wait for answers before proceeding.** Then scaffold with explicit flags:

```bash
swiftastlinttool init --path <path> --name <name>
```

Patch `Package.swift` if macOS version differs from v15. After scaffolding, delete the auto-generated entry point that conflicts with `main.swift`:

```bash
rm -f <path>/Sources/swift-ast-lint/swift-ast-lint.swift
```

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

For API reference, see [references/rule-api.md](references/rule-api.md).

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

After all rules pass tests, present:

1. How to run lint: `swift run --package-path <linter-path> swift-ast-lint <target-path>`
2. Optional automation — ask which they want:
   - **a)** Checksum cache script — skip rebuild when Rules sources unchanged
   - **b)** Makefile target — `make ast-lint`
   - **c)** Claude Code hooks / git pre-commit — auto-lint on commit
   - **d)** None

Wait for answer, then set up what they chose. See [references/setup-guide.md](references/setup-guide.md) for templates.
