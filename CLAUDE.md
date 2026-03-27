# swift-ast-lint

Minimal SwiftSyntax AST-based linting kit. Users write lint rules in pure Swift, build their own linter executable, and run it against their codebase.

## Architecture

Three modules: **SwiftASTLint** (core library), **SwiftASTLintScaffold** (package generator), **swift-ast-lint-tool** (CLI).

SwiftASTLint internal structure:
- `Linter` — Public CLI entry point (`Linter.lint(rules)`). AsyncParsableCommand thin wrapper. Bootstraps LoggingSystem.
- `LintEngine` — Internal lint execution (file collection, filtering, rule application). Unit-testable without ArgumentParser.
- `ConfigurationLoader` — YAML config via `Decodable`. Returns `nil` if file missing.
- `@LintActor` global actor isolates `LintContext` and Rule closures. No `@unchecked Sendable`, no `await` in Rule closures.
- Intersection filtering: yml > RuleSet > Rule. Each level can only narrow, never widen.
- Exit code 2 for lint errors. Compatible with Claude Code hooks.

## Development

```bash
make install-commands  # Install swiftlint, swiftformat, gitnagg via nest
make format            # Run swiftformat
make lint              # Run swiftlint --strict
make test              # Run swift test
make check             # format + lint + test
make hooks             # Set up git hooks
```

## Conventions

- Follow `.swiftlint.yml` strictly. 0 violations. All prohibited patterns are enforced by custom_rules there — do not duplicate here.
- `package` access for internal API. `public` only for user-facing API.
- DI via init: 外部依存（ファイルシステム、ネットワーク等）はprotocol経由でinitに受け取り、default parameterで本番実装を指定。staticメソッドで引数バケツリレーしない。enumではなくstructにする。
- Logging via `swift-log`. Package-level `logger` instance.
- `Codable` for config/data parsing. No manual dictionary casting.

## Testing

- Swift Testing framework (`import Testing`, `@Test`, `@Suite`, `#expect`).
- `@Suite` must have descriptive string (not just the type name).
- `FileManagerProtocol` `runInTemporaryDirectory` for temp files.
- Test `LintEngine` directly, not through `Linter` (ArgumentParser).
- Parameterized tests where applicable. 90%+ coverage target.
