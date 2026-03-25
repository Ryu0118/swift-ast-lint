# swift-ast-lint

Minimal SwiftSyntax AST-based linting kit. Users write lint rules in pure Swift, build their own linter executable, and run it against their codebase.

## Architecture

Three modules:

- **SwiftASTLint** — Core library. `Rule`, `RuleSet`, `LintContext`, `LintCommand`, `Diagnostic`, `GlobPattern`, `Configuration`. `@LintActor` global actor isolates all lint execution.
- **SwiftASTLintScaffold** — Generates user-side linter packages via `swift package init --type empty` + file templates. Uses `swift-subprocess`.
- **swift-ast-lint-tool** — CLI entry point (`swiftastlinttool init`). Wraps `SwiftASTLintScaffold`.

## Key Design Decisions

- **@LintActor global actor** — `LintContext` and Rule closures run on `@LintActor`. No `@unchecked Sendable`, no manual locks, no `await` in Rule closures.
- **Parallel file processing** — `asyncMap(numberOfConcurrentTasks: 10)` via `swift-async-operations`. Files parsed once, all applicable rules run per file.
- **ArgumentParser in LintCommand** — User-side executables get CLI args (`paths`, `--config`) for free. `LintCommand.lint(rules)` is the single entry point.
- **Intersection filtering** — yml > RuleSet > Rule. Each level can only narrow, never widen.
- **Exit code 2 for errors** — Compatible with Claude Code hooks.

## Development

```bash
make install-commands  # Install swiftlint, swiftformat, gitnagg via nest
make format            # Run swiftformat
make lint              # Run swiftlint --strict
make test              # Run swift test
make check             # format + lint + test
make hooks             # Set up git hooks
```

## Rules

- Follow `.swiftlint.yml` strictly. 0 violations policy.
- Use `package` access level, not `public`, for internal API shared within the package. `public` only for API exposed to users.
- No `print()` — use `fputs` to stderr for warnings/errors, `Swift.print` for diagnostic output.
- No legacy synchronization (`NSLock`, `DispatchQueue`). Use actors/Swift Concurrency.
- No `URL(fileURLWithPath:)` — use `URL(filePath:directoryHint:)` or `FilePath`.
- Identifier names: 3-40 chars. No single-letter variables.
- Function body max 50 lines (warning), 80 lines (error).
- Nesting max 4 levels. Extract helpers.

## Testing

- Swift Testing framework (`import Testing`, `@Test`, `@Suite`, `#expect`).
- `@Suite` must have descriptive string (not just the type name).
- Use `Ryu0118/FileManagerProtocol` `runInTemporaryDirectory` for temp files.
- Parameterized tests where applicable.
- 90%+ coverage target.

## Dependencies

| Package | Purpose |
|---------|---------|
| swift-syntax `602.0.0..<700.0.0` | AST parsing |
| swift-argument-parser | CLI for LintCommand + swiftastlinttool |
| Yams | YAML config parsing |
| swift-subprocess | Process execution in Scaffold |
| swift-async-operations | Parallel file processing |
| FileManagerProtocol (test only) | `runInTemporaryDirectory` |
