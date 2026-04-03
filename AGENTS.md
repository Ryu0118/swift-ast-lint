# swift-ast-lint

Minimal SwiftSyntax AST-based linting kit. Users write lint rules in pure Swift, build their own linter executable, and run it against their codebase.

## Architecture

Three modules: **SwiftASTLint** (core library), **SwiftASTLintScaffold** (package generator), **swift-ast-lint-tool** (CLI).

SwiftASTLint internal structure:
- `Linter` — Public CLI entry point (`Linter.lint(rules)`). AsyncParsableCommand thin wrapper. Bootstraps LoggingSystem. `--fix` flag for autofix mode.
- `LintEngine` — Internal lint execution (file collection, filtering, rule application). Unit-testable without ArgumentParser. Fix mode: `fixAndOutputDiagnostics()` collects FixIts, applies via `FixApplier`, writes back.
- `FixApplier` — Applies SwiftSyntax `FixIt` edits to source text. Uses `FixIt.edits` (public API) → `SourceEdit` → UTF-8 byte replacement. Descending offset order, overlap skipping.
- `LintContext` — `report(on:message:severity:)` for unfixable, `reportWithFix(on:message:severity:fixIts:)` for fixable violations. FixIts use SwiftDiagnostics `FixIt`/`FixIt.Change` directly.
- `SimpleFixItMessage` — Public `FixItMessage` implementation for rule authors.
- `ConfigurationLoader` — YAML config via `Decodable`. Returns `nil` if file missing.
- Intersection filtering: disabled_rules > yml paths > per-rule paths. Each level can only narrow, never widen.
- Exit code 2 for lint errors (standalone usage).
- **Claude Code hook integration**: The CLI outputs plain text, not JSON. For PostToolUse hooks (exit 0 + JSON stdout), a wrapper script is required to convert the CLI output into the expected JSON format: `{"decision":"block","reason":"<lint error details>"}`. Exit 2 is NOT compatible with PostToolUse hooks — exit 2 causes stderr to appear only in verbose mode (Ctrl+O) and JSON stdout is ignored. PreToolUse hooks use a different JSON format with `"permissionDecision"`.
- Depends on `SwiftDiagnostics` (from swift-syntax) for `FixIt`, `FixIt.Change`, `SourceEdit`. Does NOT use `@_spi(FixItApplier)` — fix application is self-contained in `FixApplier`.

## Development

```bash
make install-commands  # Install swiftlint, swiftformat, gitnagg via nest
make format            # Run swiftformat
make lint              # Run swiftlint --strict
make test              # Run swift test
make ast-lint          # Run AST linter (cached build)
make check             # format + lint + ast-lint + test
make hooks             # Set up git hooks
```

## Conventions

- Follow `.swiftlint.yml` strictly. 0 violations. All prohibited patterns are enforced by custom_rules there — do not duplicate here.
- `package` access for internal API. `public` only for user-facing API.
- DI via init: inject external dependencies (file system, network, etc.) through protocols in the initializer with default parameters for production implementations. No static method argument forwarding chains. Use structs, not enums.
- Logging via `swift-log`. Package-level `logger` instance.
- `Codable` for config/data parsing. No manual dictionary casting.

## Testing

- Swift Testing framework (`import Testing`, `@Test`, `@Suite`, `#expect`).
- `@Suite` must have descriptive string (not just the type name).
- `FileManagerProtocol` `runInTemporaryDirectory` for temp files.
- Test `LintEngine` directly, not through `Linter` (ArgumentParser).
- Parameterized tests where applicable. 90%+ coverage target.
