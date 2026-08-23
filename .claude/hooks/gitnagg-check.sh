#!/bin/sh

allow() {
  printf '{"decision":"allow"}\n'
  exit 0
}

SRCROOT=$(git rev-parse --show-toplevel 2>/dev/null) || allow
[ -f "$SRCROOT/.gitnagg.yml" ] || allow

if [ -x "$SRCROOT/.nest/bin/gitnagg" ]; then
  GITNAGG="$SRCROOT/.nest/bin/gitnagg"
elif command -v gitnagg >/dev/null 2>&1; then
  GITNAGG=$(command -v gitnagg)
else
  allow
fi

if ! GITNAGG_OUTPUT=$("$GITNAGG" check --config "$SRCROOT/.gitnagg.yml" --claude-hook 2>&1); then
  REASON=$(printf '%s' "$GITNAGG_OUTPUT" | jq -Rs .)
  printf '{"decision":"block","reason":%s}\n' "$REASON"
  exit 0
fi

allow
