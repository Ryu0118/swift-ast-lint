#!/bin/sh
FILE_PATH=$(jq -r '.file_path // .tool_input.file_path // ""')
SRCROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0

HAS_ERROR=0
ALL_REASONS=""

# Swift-specific: format + lint
if echo "$FILE_PATH" | grep -q '\.swift$'; then
  # Resolve relative path
  if [ ! -f "$FILE_PATH" ] && [ -f "$SRCROOT/$FILE_PATH" ]; then
    FILE_PATH="$SRCROOT/$FILE_PATH"
  fi

  if [ -f "$FILE_PATH" ]; then
    # 1. swiftformat
    if [ -x "$SRCROOT/.nest/bin/swiftformat" ]; then
      SWIFTFORMAT="$SRCROOT/.nest/bin/swiftformat"
    elif command -v swiftformat >/dev/null 2>&1; then
      SWIFTFORMAT=$(command -v swiftformat)
    else
      SWIFTFORMAT=""
    fi
    if [ -n "$SWIFTFORMAT" ] && [ -f "$SRCROOT/.swiftformat" ]; then
      "$SWIFTFORMAT" --config "$SRCROOT/.swiftformat" "$FILE_PATH" 2>/dev/null || true
    fi

    # 2. swiftlint
    if [ -x "$SRCROOT/.nest/bin/swiftlint" ]; then
      SWIFTLINT="$SRCROOT/.nest/bin/swiftlint"
    elif command -v swiftlint >/dev/null 2>&1; then
      SWIFTLINT=$(command -v swiftlint)
    else
      SWIFTLINT=""
    fi
    if [ -n "$SWIFTLINT" ] && [ -f "$SRCROOT/.swiftlint.yml" ]; then
      LINT_OUTPUT=$("$SWIFTLINT" lint --config "$SRCROOT/.swiftlint.yml" --strict --quiet "$FILE_PATH" 2>&1) || true
      if [ -n "$LINT_OUTPUT" ]; then
        echo "$LINT_OUTPUT" >&2
        ALL_REASONS="${ALL_REASONS}${LINT_OUTPUT}\n"
        HAS_ERROR=1
      fi
    fi

    # 3. ast-lint (changed file only)
    if [ -x "$SRCROOT/scripts/ast-lint.sh" ]; then
      AST_OUTPUT=$("$SRCROOT/scripts/ast-lint.sh" "$FILE_PATH" 2>&1) || true
      if [ -n "$AST_OUTPUT" ]; then
        echo "$AST_OUTPUT" >&2
        ALL_REASONS="${ALL_REASONS}${AST_OUTPUT}\n"
        HAS_ERROR=1
      fi
    fi
  fi
fi

# 4. gitnagg (always, regardless of file type)
if [ -x "$SRCROOT/.nest/bin/gitnagg" ] && [ -f "$SRCROOT/.gitnagg.yml" ]; then
  set +e
  NAGG_OUTPUT=$("$SRCROOT/.nest/bin/gitnagg" check --config "$SRCROOT/.gitnagg.yml" 2>&1)
  NAGG_STATUS=$?
  set -e
  if [ "$NAGG_STATUS" -ne 0 ]; then
    echo "$NAGG_OUTPUT" >&2
    ALL_REASONS="${ALL_REASONS}${NAGG_OUTPUT}\n"
    HAS_ERROR=1
  fi
fi

# Block with all collected diagnostics
if [ "$HAS_ERROR" -ne 0 ]; then
  REASON=$(printf '%b' "$ALL_REASONS" | jq -Rs .)
  printf '{"decision":"block","reason":%s}\n' "$REASON"
  exit 2
fi

exit 0
