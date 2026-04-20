#!/usr/bin/env bash
# Replace tmux's full hostname token with its short-host token so the status
# bar shows the local short hostname instead of a fully qualified one.

status_left="$(tmux show-option -gqv status-left 2>/dev/null)" || exit 0

if [[ -n "$status_left" ]]; then
  tmux set-option -g status-left "${status_left//#H/#h}"
fi
