#!/bin/bash
#
# ntfy-notify.sh: Send push notifications via ntfy.sh
#
# ntfy is the SIMPLEST option - no account, no API key, no setup.
# Just pick a unique topic name and subscribe to it in the app.
#
# Setup:
#   1. Install ntfy app (iOS: App Store, Android: Play Store or F-Droid)
#   2. Subscribe to your topic (use a random string for privacy)
#   3. That's it. Seriously.
#
# Security note: Anyone who knows your topic can send you notifications,
# so use a random string like "claude-dev-a8f3k2m9x" not "john-notifications"
#
# Usage: Called automatically by Claude Code hooks
# Test:  ./ntfy-notify.sh test

# ============================================
# CONFIGURATION
# ============================================

# Option 1: Use the free public server (easiest)
NTFY_SERVER="https://ntfy.sh"

# Option 2: Self-host ntfy and use your own server
# NTFY_SERVER="https://ntfy.yourdomain.com"

# Your topic name - make it unique and hard to guess!
# Example: claude-dev-$(openssl rand -hex 4) → claude-dev-a8f3k2m9
NTFY_TOPIC="claude-dev-a8f3k2m9"

# Priority: min, low, default, high, urgent
# "high" will make noise even in Do Not Disturb on some phones
PRIORITY="high"

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
