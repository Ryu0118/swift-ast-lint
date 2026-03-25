#!/bin/sh
# Claude Code PreToolUse hook: architecture constraints
# Runs before Edit/Write to block forbidden patterns

FILE_PATH=$(jq -r '.tool_input.file_path // ""')
NEW_CONTENT=$(jq -r '.tool_input.new_string // .tool_input.content // ""')

# Skip non-Swift files
echo "$FILE_PATH" | grep -q '\.swift$' || exit 0

# Block swiftlint:disable additions
if echo "$NEW_CONTENT" | grep -q 'swiftlint:disable'; then
  echo '{"decision":"block","reason":"swiftlint:disable is not allowed without explicit user approval. Fix the code instead."}'
  exit 2
fi

exit 0
