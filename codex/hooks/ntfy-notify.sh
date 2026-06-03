#!/usr/bin/env bash
# ABOUTME: Send push notifications via ntfy.sh when Codex hooks fire.
# ABOUTME: Reads NTFY_TOPIC from env; exits silently when notifications are not configured.

set -euo pipefail

if [[ -z "${NTFY_TOPIC:-}" && -f "$HOME/.zsh/env/optional/private.zsh" ]]; then
  # Keep stdout clean for hook hosts that parse command output.
  # shellcheck disable=SC1091
  source "$HOME/.zsh/env/optional/private.zsh" >/dev/null 2>&1 || true
fi

NTFY_SERVER="${NTFY_SERVER:-https://ntfy.sh}"
EVENT_TYPE="${1:-unknown}"
EVENT_JSON="$(cat)"

PROJECT_NAME="$(basename "$PWD")"
HOST_NAME="${NTFY_HOST_LABEL:-$(hostname -s)}"
SESSION_ID="$(printf '%s' "$EVENT_JSON" | jq -r '.session_id // empty' 2>/dev/null || true)"

DEDUP_DIR="/tmp/ntfy-codex-dedup"
SESSION_DIR="/tmp/ntfy-codex-sessions"
DEDUP_WINDOW=15
SESSION_TTL_MIN=1440

mkdir -p "$DEDUP_DIR" "$SESSION_DIR"
find "$DEDUP_DIR" -type f -mmin +1 -delete 2>/dev/null || true
find "$SESSION_DIR" -type f -mmin +"$SESSION_TTL_MIN" -delete 2>/dev/null || true

dedup_check() {
  local key="$1"
  local hash
  local lockfile

  hash="$(printf '%s' "$key" | md5 -q 2>/dev/null || printf '%s' "$key" | md5sum | cut -d' ' -f1)"
  lockfile="$DEDUP_DIR/$hash"

  if [[ -f "$lockfile" ]]; then
    local now file_mtime age
    now="$(date +%s)"
    file_mtime="$(stat -f%m "$lockfile" 2>/dev/null || stat -c%Y "$lockfile" 2>/dev/null || echo 0)"
    age=$((now - file_mtime))
    if ((age < DEDUP_WINDOW)); then
      return 1
    fi
  fi

  touch "$lockfile"
  return 0
}

cache_prompt_title() {
  [[ -n "$SESSION_ID" ]] || return 0

  local cache_file prompt_text title
  cache_file="$SESSION_DIR/$SESSION_ID"

  [[ ! -f "$cache_file" ]] || return 0

  prompt_text="$(printf '%s' "$EVENT_JSON" | jq -r '.prompt // .message // empty' 2>/dev/null || true)"
  title="$(printf '%s' "$prompt_text" | awk 'NF{print; exit}' | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//')"
  if [[ ${#title} -gt 60 ]]; then
    title="${title:0:57}..."
  fi

  [[ -n "$title" ]] && printf '%s' "$title" > "$cache_file"
}

if [[ "$EVENT_TYPE" == "prompt" ]]; then
  cache_prompt_title
  exit 0
fi

[[ -n "${NTFY_TOPIC:-}" ]] || exit 0

case "$EVENT_TYPE" in
  question)
    PRIORITY="high"
    TAGS="question"
    MESSAGE="$(printf '%s' "$EVENT_JSON" | jq -r '
      .tool_input.question //
      .tool_input.questions[0].question //
      .tool_input.message //
      .message //
      empty
    ' 2>/dev/null || true)"
    [[ -n "$MESSAGE" && "$MESSAGE" != "null" ]] || MESSAGE="Needs your input"
    ;;
  complete)
    PRIORITY="default"
    TAGS="white_check_mark"
    MESSAGE="Task finished"
    ;;
  *)
    PRIORITY="default"
    TAGS="robot"
    MESSAGE="Hook fired: $EVENT_TYPE"
    ;;
esac

if [[ ${#MESSAGE} -gt 200 ]]; then
  MESSAGE="${MESSAGE:0:197}..."
fi

if [[ -n "$SESSION_ID" && -f "$SESSION_DIR/$SESSION_ID" ]]; then
  CACHED_TITLE="$(cat "$SESSION_DIR/$SESSION_ID")"
  MESSAGE="$(printf '%s\n%s' "$CACHED_TITLE" "$MESSAGE")"
fi

TITLE="Codex on $HOST_NAME: $PROJECT_NAME"

dedup_check "${EVENT_TYPE}:${MESSAGE}" || exit 0

curl -sf \
  -H "Title: $TITLE" \
  -H "Priority: $PRIORITY" \
  -H "Tags: $TAGS" \
  -d "$MESSAGE" \
  "$NTFY_SERVER/$NTFY_TOPIC" >/dev/null 2>&1 &

exit 0
