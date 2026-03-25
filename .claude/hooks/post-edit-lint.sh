#!/bin/sh
FILE_PATH=$(jq -r '.file_path // .tool_input.file_path // ""')
echo "$FILE_PATH" | grep -q '\.swift$' || exit 0

SRCROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0

# Cursor may pass a repo-relative path; resolve against SRCROOT when needed.
if [ ! -f "$FILE_PATH" ] && [ -f "$SRCROOT/$FILE_PATH" ]; then
  FILE_PATH="$SRCROOT/$FILE_PATH"
fi
[ -f "$FILE_PATH" ] || exit 0

if [ -x "$SRCROOT/.nest/bin/swiftlint" ]; then
  SWIFTLINT="$SRCROOT/.nest/bin/swiftlint"
else
  SWIFTLINT=$(command -v swiftlint) || exit 0
fi
[ -f "$SRCROOT/.swiftlint.yml" ] || exit 0

LINT_OUTPUT=$("$SWIFTLINT" lint --config "$SRCROOT/.swiftlint.yml" --strict --quiet "$FILE_PATH" 2>&1) || true
if [ -n "$LINT_OUTPUT" ]; then
  echo "$LINT_OUTPUT" >&2
  REASON=$(printf '%s' "$LINT_OUTPUT" | jq -Rs .)
  printf '{"decision":"block","reason":%s}\n' "$REASON"
  exit 2
fi

exit 0
