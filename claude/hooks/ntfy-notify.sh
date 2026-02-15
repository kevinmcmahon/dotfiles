#!/bin/bash
# ABOUTME: Send push notifications via ntfy.sh when Claude Code hooks fire.
# ABOUTME: Reads NTFY_TOPIC from env; exits silently if unset (safe on unconfigured machines).
#
# ntfy is the SIMPLEST option - no account, no API key, no setup.
# Just pick a unique topic name and subscribe to it in the app.
#
# Setup:
#   1. Install ntfy app (iOS: App Store, Android: Play Store or F-Droid)
#   2. Subscribe to your topic (use a random string for privacy)
#   3. Add to ~/.zsh/env/optional/private.zsh:
#        export NTFY_TOPIC="your-unique-topic"
#      Optionally also set:
#        export NTFY_SERVER="https://ntfy.yourdomain.com"  # default: https://ntfy.sh
#        export NTFY_PRIORITY="urgent"                     # default: high
#
# Security note: Anyone who knows your topic can send you notifications,
# so use a random string like "claude-dev-a8f3k2m9x" not "john-notifications"
#
# Usage: Called automatically by Claude Code hooks
# Test:  NTFY_TOPIC=test-topic ./ntfy-notify.sh test

# ============================================
# CONFIGURATION (from environment)
# ============================================

# NTFY_TOPIC is required — exit silently if unset so hooks don't break
# on machines that haven't configured ntfy yet.
if [[ -z "${NTFY_TOPIC:-}" ]]; then
  exit 0
fi

NTFY_SERVER="${NTFY_SERVER:-https://ntfy.sh}"
PRIORITY="${NTFY_PRIORITY:-high}"

# ============================================
# SCRIPT LOGIC
# ============================================

EVENT_TYPE="${1:-unknown}"
EVENT_DATA="${CLAUDE_HOOK_EVENT_DATA:-}"
PROJECT_NAME=$(basename "$PWD")

# Build the message
TITLE="🤖 $PROJECT_NAME"
MESSAGE="needs your input"

if [[ -n "$EVENT_DATA" ]]; then
    QUESTION=$(echo "$EVENT_DATA" | jq -r '
        .tool_input.question // 
        .tool_input.questions[0].question // 
        .tool_input.message //
        "needs your input"
    ' 2>/dev/null)
    
    if [[ -n "$QUESTION" && "$QUESTION" != "null" ]]; then
        [[ ${#QUESTION} -gt 200 ]] && QUESTION="${QUESTION:0:200}..."
        MESSAGE="$QUESTION"
    fi
fi

# Add emoji based on event type
case "$EVENT_TYPE" in
    question) TITLE="❓ $PROJECT_NAME" ;;
    error)    TITLE="❌ $PROJECT_NAME"; MESSAGE="Error occurred" ;;
    complete) TITLE="✅ $PROJECT_NAME"; MESSAGE="Task complete" ;;
esac

# Send to ntfy
# The magic: just POST to ntfy.sh/your-topic
curl -sf \
    -H "Title: $TITLE" \
    -H "Priority: $PRIORITY" \
    -H "Tags: robot" \
    -d "$MESSAGE" \
    "$NTFY_SERVER/$NTFY_TOPIC" > /dev/null 2>&1 &

exit 0
