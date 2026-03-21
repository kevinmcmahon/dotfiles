#!/usr/bin/env bash
# Replaces Nerd Font / Powerline glyphs in tmux status options with ASCII
# equivalents so the status bar renders cleanly in terminals without a patched
# font (e.g. Termius with plain JetBrainsMono).

replace_glyphs() {
  local val="$1"
  echo "$val" | sed \
    -e 's///g' \
    -e 's///g' \
    -e 's///g' \
    -e 's// >/g' \
    -e 's// */g' \
    -e 's// -/g'
}

for opt in status-left status-right; do
  val=$(tmux show-option -gv "$opt" 2>/dev/null) || continue
  [[ -n "$val" ]] && tmux set-option -g "$opt" "$(replace_glyphs "$val")"
done

for opt in window-status-current-format window-status-format; do
  val=$(tmux show-window-option -gv "$opt" 2>/dev/null) || continue
  [[ -n "$val" ]] && tmux set-window-option -g "$opt" "$(replace_glyphs "$val")"
done
