#!/bin/bash
# Fast AST lint runner with build cache.
# Uses prebuilt binary when Rules sources and Package.swift haven't changed.
set -euo pipefail

LINTER_DIR="swift-ast-linter"
BINARY="$LINTER_DIR/.build/debug/swift-ast-lint"
CHECKSUM_FILE="$LINTER_DIR/.build/.ast-lint-checksum"
LINT_ARGS=("${@:-.}")

# Compute combined checksum of Rules sources + Package.swift
current_checksum() {
    cat "$LINTER_DIR"/Sources/Rules/*.swift "$LINTER_DIR/Package.swift" \
        | shasum -a 256 | cut -d' ' -f1
}

CURRENT=$(current_checksum)

# Check if cached binary is up-to-date
if [ -f "$BINARY" ] && [ -f "$CHECKSUM_FILE" ]; then
    CACHED=$(cat "$CHECKSUM_FILE")
    if [ "$CURRENT" = "$CACHED" ]; then
        exec "$BINARY" "${LINT_ARGS[@]}"
    fi
fi

# Build and cache
echo "Building swift-ast-lint..." >&2
swift build --package-path "$LINTER_DIR" 2>&1 | tail -1 >&2

mkdir -p "$(dirname "$CHECKSUM_FILE")"
echo "$CURRENT" > "$CHECKSUM_FILE"

exec "$BINARY" "${LINT_ARGS[@]}"
