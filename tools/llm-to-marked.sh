#!/bin/bash
# Generate unique filename with random hash
HASH=$(openssl rand -hex 4)
TEMP_FILE="/tmp/llm_output_${HASH}.md"

# Run llm command and open in Marked 2
llm "$@" > "$TEMP_FILE" && open -a "Marked 2" "$TEMP_FILE"
