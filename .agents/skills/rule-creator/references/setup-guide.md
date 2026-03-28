# Setup Guide — Lint Execution and Automation

Templates for setting up lint execution in the target project after scaffolding a new linter.

## Checksum cache script

Create `scripts/ast-lint.sh` in the **target project** (not the linter project). Replace `<relative-path-to-linter>` with the actual path.

```bash
#!/bin/bash
# Fast AST lint runner with build cache.
# Skips rebuild when Rules sources and Package.swift are unchanged.
set -euo pipefail

LINTER_DIR="<relative-path-to-linter>"
BINARY="$LINTER_DIR/.build/debug/swift-ast-lint"
CHECKSUM_FILE="$LINTER_DIR/.build/.ast-lint-checksum"
LINT_ARGS=("${@:-.}")

current_checksum() {
    cat "$LINTER_DIR"/Sources/Rules/*.swift "$LINTER_DIR/Package.swift" \
        | shasum -a 256 | cut -d' ' -f1
}

CURRENT=$(current_checksum)

if [ -f "$BINARY" ] && [ -f "$CHECKSUM_FILE" ]; then
    CACHED=$(cat "$CHECKSUM_FILE")
    if [ "$CURRENT" = "$CACHED" ]; then
        exec "$BINARY" "${LINT_ARGS[@]}"
    fi
fi

echo "Building swift-ast-lint..." >&2
swift build --package-path "$LINTER_DIR" 2>&1 | tail -1 >&2

mkdir -p "$(dirname "$CHECKSUM_FILE")"
echo "$CURRENT" > "$CHECKSUM_FILE"

exec "$BINARY" "${LINT_ARGS[@]}"
```

After creating: `chmod +x scripts/ast-lint.sh`

## Makefile target

```makefile
ast-lint:
	./scripts/ast-lint.sh ./Sources
```

## Claude Code hooks

Add to `.claude/settings.json` in the target project:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "./scripts/ast-lint.sh ./Sources"
          }
        ]
      }
    ]
  }
}
```

## Git pre-commit hook

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash
./scripts/ast-lint.sh ./Sources
```

After creating: `chmod +x .git/hooks/pre-commit`
