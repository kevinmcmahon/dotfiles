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
#   prompt     - UserPromptSubmit: derives a session title from the user's
#                first prompt, caches it, and emits hookSpecificOutput JSON
#                so Claude Code renames the session. Sends no push.
#   question   - PreToolUse/AskUserQuestion: Claude asks a clarifying question
#   permission - Notification/permission_prompt: a tool needs your approval
#   idle       - Notification/idle_prompt: Claude has been waiting 60s+ for input
#   complete   - Stop: Claude finished its task
#
# All push events (question/permission/idle/complete) read the cached
# session title and prepend it to the notification body, so multi-session
# users can tell which session is pinging them from the lock screen.
#
# Usage: Called automatically by Claude Code hooks (event data arrives on stdin)
# Test:  echo '{"tool_input":{"question":"Use React or Vue?"}}' | NTFY_TOPIC=test-topic ./ntfy-notify.sh question
#        echo '{"session_id":"abc","prompt":"build a thing"}' | ./ntfy-notify.sh prompt

# ============================================
# CONFIGURATION (from environment)
# ============================================

# Claude Code hooks don't inherit the parent shell's environment,
# so source the private env file if vars aren't already set.
# Redirect to /dev/null: the prompt event handler emits JSON on stdout,
# and any stray output from the sourced file would corrupt that response.
if [[ -z "${NTFY_TOPIC:-}" && -f ~/.zsh/env/optional/private.zsh ]]; then
  source ~/.zsh/env/optional/private.zsh >/dev/null 2>&1
fi

# NTFY_TOPIC is required for the curl push path — but the prompt event
# handler runs unconditionally below so the session-rename feature works
# even on machines without ntfy configured. The push path bails after
# event parsing if NTFY_TOPIC is still missing.

NTFY_SERVER="${NTFY_SERVER:-https://ntfy.sh}"

# ============================================
# DEDUPLICATION
# ============================================

DEDUP_DIR="/tmp/ntfy-claude-dedup"
DEDUP_WINDOW=15

mkdir -p "$DEDUP_DIR"

# Remove stale lockfiles (older than 60s)
find "$DEDUP_DIR" -type f -mmin +1 -delete 2>/dev/null

# ============================================
# SESSION TITLE CACHE
# ============================================
#
# UserPromptSubmit hooks can set a Claude Code session title via
# hookSpecificOutput.sessionTitle, but that title is NOT echoed back to
# subsequent hook events. To make ntfy pushes carry session context, the
# prompt handler caches the derived title here, keyed by .session_id, and
# the push handlers read it back to prepend to the notification body.

SESSION_DIR="/tmp/ntfy-claude-sessions"
SESSION_TTL_MIN=1440  # 24h — long enough for overnight sessions

mkdir -p "$SESSION_DIR"

# Remove stale session title caches
find "$SESSION_DIR" -type f -mmin +"$SESSION_TTL_MIN" -delete 2>/dev/null

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
SESSION_ID=$(echo "$EVENT_JSON" | jq -r '.session_id // empty' 2>/dev/null)

# ============================================
# PROMPT EVENT — SET SESSION TITLE
# ============================================
#
# Handled before the NTFY_TOPIC guard so the session-rename feature works
# even on machines without ntfy configured. Emits JSON on stdout for
# Claude Code to parse and exits cleanly without sending a push (a push
# per prompt would be spam).

if [[ "$EVENT_TYPE" == "prompt" ]]; then
  if [[ -n "$SESSION_ID" ]]; then
    CACHE_FILE="$SESSION_DIR/$SESSION_ID"

    # First-prompt-only policy: only derive a new title if no cache file
    # exists yet. Continuation prompts ("yes", "continue", "now do X")
    # leave the original title intact.
    if [[ ! -f "$CACHE_FILE" ]]; then
      PROMPT_TEXT=$(echo "$EVENT_JSON" | jq -r '.prompt // empty' 2>/dev/null)
      # Claude Code wraps pasted text in <pasted_content id="..."> tags; drop
      # the tags so the title is the first real line, not the wrapper.
      # Then: first non-empty line, whitespace collapsed, trimmed
      TITLE=$(printf '%s' "$PROMPT_TEXT" \
        | sed -E 's#</?pasted_content[^>]*>##g' \
        | awk 'NF{print; exit}' \
        | tr -s '[:space:]' ' ' \
        | sed 's/^ //; s/ $//')
      if [[ ${#TITLE} -gt 60 ]]; then
        TITLE="${TITLE:0:57}..."
      fi
      [[ -n "$TITLE" ]] && printf '%s' "$TITLE" > "$CACHE_FILE"
    fi

    # Always emit the cached title so re-prompts don't lose the rename.
    # jq --arg shields the JSON output from any quoting hazards in the
    # title text — never string-interpolate user content into JSON.
    if [[ -f "$CACHE_FILE" ]]; then
      CACHED_TITLE=$(cat "$CACHE_FILE")
      jq -nc --arg t "$CACHED_TITLE" \
        '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", sessionTitle: $t}}'
    fi
  fi
  exit 0
fi

# ============================================
# PUSH EVENTS REQUIRE NTFY_TOPIC
# ============================================
#
# All remaining event types send a curl push. Bail silently if ntfy isn't
# configured on this machine.

if [[ -z "${NTFY_TOPIC:-}" ]]; then
  exit 0
fi

# last_assistant_line — the first sentence of Claude's latest reply, as plain
# text up to 200 characters, or nothing. Prefers the event's own
# last_assistant_message field when the hook payload carries one, else reads
# the tail of the session transcript (JSONL) named by transcript_path.
last_assistant_line() {
  local text transcript
  text=$(echo "$EVENT_JSON" | jq -r '.last_assistant_message // empty' 2>/dev/null)
  if [[ -z "$text" ]]; then
    transcript=$(echo "$EVENT_JSON" | jq -r '.transcript_path // empty' 2>/dev/null)
    [[ -n "$transcript" && -f "$transcript" ]] || return 0
    # The last assistant entry that holds text; entries are one JSON per line.
    text=$(tail -n 400 "$transcript" \
      | jq -c 'select(.type=="assistant") | [.message.content[]? | select(.type=="text") | .text] | join("\n") | select(length > 0)' 2>/dev/null \
      | tail -n 1 | jq -r '.' 2>/dev/null)
  fi
  [[ -n "$text" ]] || return 0
  # First non-empty line, markdown marks removed, cut at the first sentence end.
  printf '%s' "$text" \
    | awk 'NF{print; exit}' \
    | sed -E 's/^[#>*-]+ +//; s/\*\*//g; s/`//g' \
    | tr -s '[:space:]' ' ' \
    | sed -E 's/^ //; s/ $//; s/([.!?])( .*)?$/\1/' \
    | cut -c1-200
}

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
    LAST=$(last_assistant_line)
    MESSAGE="Waiting for your input${LAST:+: $LAST}"
    ;;

  complete)
    PRIORITY="default"
    ICON="✅"
    LAST=$(last_assistant_line)
    MESSAGE="${LAST:-Task finished}"
    ;;

  *)
    PRIORITY="default"
    ICON="🤖"
    MESSAGE="Hook fired: $EVENT_TYPE"
    ;;
esac

TITLE="$ICON $HOST_NAME: $PROJECT_NAME"

# Prepend the cached session title (set by an earlier UserPromptSubmit
# hook on this same session) so the lock-screen preview tells you which
# Claude session is pinging you, not just which project.
if [[ -n "$SESSION_ID" && -f "$SESSION_DIR/$SESSION_ID" ]]; then
  CACHED_TITLE=$(cat "$SESSION_DIR/$SESSION_ID")
  MESSAGE=$(printf '📝 %s\n%s' "$CACHED_TITLE" "$MESSAGE")
fi

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
