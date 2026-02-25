#!/bin/bash
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

if echo "$COMMAND" | grep -qE '\bgit\s+(commit|push)\b'; then
  echo "Blocked: Only humans do commits, not Claude." >&2
  exit 2
fi

exit 0
