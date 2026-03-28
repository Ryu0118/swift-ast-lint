#!/bin/bash
# Blocks edits to skill directories on first attempt per session.
# Second attempt in the same session is allowed.
set -o pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

# Check if file is in a skill directory
if [[ "$FILE_PATH" != *".agents/skills/"* ]] && [[ "$FILE_PATH" != *".claude/skills/"* ]]; then
  exit 0
fi

STATE_DIR="${HOME}/.cache/claude-code/hooks"
mkdir -p "$STATE_DIR"
STATE_FILE="${STATE_DIR}/skill-edit-warning-${SESSION_ID}.state"

if [ -f "$STATE_FILE" ]; then
  exit 0
fi

touch "$STATE_FILE"

cat >&2 <<'EOF'
Stop. Load skill-creator skill first before editing skill files:

  /skill-creator

Next attempt will be allowed.
EOF

exit 2
