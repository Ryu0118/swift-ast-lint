#!/bin/bash
# Fast AST lint runner with build cache.
# Uses prebuilt binary when Rules sources and Package.swift haven't changed.
#
# Works correctly in git worktrees: swift-ast-linter is always resolved from
# the main worktree root so that Package.swift's `.package(path: "..")` always
# refers to the canonical "swift-ast-lint" package regardless of which worktree
# directory name SPM would otherwise pick up.
set -euo pipefail

# Resolve the main worktree root via --git-common-dir (works in both main and
# linked worktrees). In the main worktree --git-common-dir returns ".git"; we
# resolve it to an absolute path and then take its parent.
GIT_COMMON_DIR=$(git rev-parse --git-common-dir)
MAIN_ROOT=$(cd "$(dirname "$GIT_COMMON_DIR")" && pwd)

LINTER_DIR="$MAIN_ROOT/swift-ast-linter"
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
