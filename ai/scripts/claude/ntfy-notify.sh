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
#
# Security note: Anyone who knows your topic can send you notifications,
# so use a random string like "claude-dev-a8f3k2m9x" not "john-notifications"
#
# Hook event types and their triggers:
#   question   - PreToolUse/AskUserQuestion: Claude asks a clarifying question
#   permission - Notification/permission_prompt: a tool needs your approval
#   idle       - Notification/idle_prompt: Claude has been waiting 60s+ for input
#   complete   - Stop: Claude finished its task
#
# Usage: Called automatically by Claude Code hooks (event data arrives on stdin)
# Test:  echo '{"tool_input":{"question":"Use React or Vue?"}}' | NTFY_TOPIC=test-topic ./ntfy-notify.sh question

# ============================================
# CONFIGURATION (from environment)
# ============================================

# Claude Code hooks don't inherit the parent shell's environment,
# so source the private env file if vars aren't already set.
if [[ -z "${NTFY_TOPIC:-}" && -f ~/.zsh/env/optional/private.zsh ]]; then
  source ~/.zsh/env/optional/private.zsh
fi

# NTFY_TOPIC is required — exit silently if unset so hooks don't break
# on machines that haven't configured ntfy yet.
if [[ -z "${NTFY_TOPIC:-}" ]]; then
  exit 0
fi

NTFY_SERVER="${NTFY_SERVER:-https://ntfy.sh}"

# ============================================
# DEDUPLICATION
# ============================================

DEDUP_DIR="/tmp/ntfy-claude-dedup"
DEDUP_WINDOW=15

mkdir -p "$DEDUP_DIR"

# Remove stale lockfiles (older than 60s)
find "$DEDUP_DIR" -type f -mmin +1 -delete 2>/dev/null

dedup_check() {
  local key="$1"
  local hash
  hash=$(printf '%s' "$key" | md5 -q 2>/dev/null || printf '%s' "$key" | md5sum | cut -d' ' -f1)
  local lockfile="$DEDUP_DIR/$hash"

  if [[ -f "$lockfile" ]]; then
    local now file_mtime age
    now=$(date +%s)
    file_mtime=$(stat -f%m "$lockfile" 2>/dev/null || stat -c%Y "$lockfile" 2>/dev/null || echo 0)
    age=$(( now - file_mtime ))
    if (( age < DEDUP_WINDOW )); then
      return 1
    fi
  fi

  touch "$lockfile"
  return 0
}

# ============================================
# PARSE EVENT
# ============================================

EVENT_TYPE="${1:-unknown}"
EVENT_JSON=$(cat)

PROJECT_NAME=$(basename "$PWD")
HOST_NAME="${NTFY_HOST_LABEL:-$(hostname -s)}"

# ============================================
# BUILD MESSAGE PER EVENT TYPE
# ============================================

case "$EVENT_TYPE" in
  question)
    PRIORITY="high"
    ICON="❓"
    QUESTION=$(echo "$EVENT_JSON" | jq -r '
      .tool_input.question //
      .tool_input.questions[0].question //
      .tool_input.message //
      empty
    ' 2>/dev/null)
    if [[ -n "$QUESTION" && "$QUESTION" != "null" ]]; then
      [[ ${#QUESTION} -gt 200 ]] && QUESTION="${QUESTION:0:200}..."
      MESSAGE="$QUESTION"
    else
      MESSAGE="Needs your input"
    fi
    ;;

  permission)
    PRIORITY="urgent"
    ICON="🔐"
    # Notification events provide a message field with the prompt text
    TOOL_MSG=$(echo "$EVENT_JSON" | jq -r '.message // empty' 2>/dev/null)
    if [[ -n "$TOOL_MSG" && "$TOOL_MSG" != "null" ]]; then
      [[ ${#TOOL_MSG} -gt 200 ]] && TOOL_MSG="${TOOL_MSG:0:200}..."
      MESSAGE="$TOOL_MSG"
    else
      MESSAGE="A tool needs your approval"
    fi
    ;;

  idle)
    PRIORITY="default"
    ICON="💤"
    MESSAGE="Waiting for your input"
    ;;

  complete)
    PRIORITY="default"
    ICON="✅"
    MESSAGE="Task finished"
    ;;

  *)
    PRIORITY="default"
    ICON="🤖"
    MESSAGE="Hook fired: $EVENT_TYPE"
    ;;
esac

TITLE="$ICON $HOST_NAME: $PROJECT_NAME"

# ============================================
# SEND (with dedup guard)
# ============================================

if ! dedup_check "${EVENT_TYPE}:${MESSAGE}"; then
  exit 0
fi

curl -sf \
    -H "Title: $TITLE" \
    -H "Priority: $PRIORITY" \
    -H "Tags: robot" \
    -d "$MESSAGE" \
    "$NTFY_SERVER/$NTFY_TOPIC" > /dev/null 2>&1 &

exit 0
